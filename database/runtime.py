from contextlib import contextmanager
from hashlib import pbkdf2_hmac, sha256
from hmac import compare_digest
from pathlib import Path
import base64
import secrets
import sqlite3
from tools.build_assets import statements

ROOT = Path(__file__).resolve().parents[1]

def password_hash(password, salt=None):
    if len(password)<10:
        raise ValueError('Password must have at least 10 characters')
    salt = salt or secrets.token_bytes(16)
    digest = pbkdf2_hmac('sha256',password.encode(),salt,600000)
    return 'pbkdf2_sha256$600000$'+base64.b64encode(salt).decode()+'$'+base64.b64encode(digest).decode()

def verify_password(password, encoded):
    algorithm, rounds, salt, digest = encoded.split('$')
    if algorithm!='pbkdf2_sha256' or rounds!='600000':
        return False
    return compare_digest(pbkdf2_hmac('sha256',password.encode(),base64.b64decode(salt),int(rounds)),base64.b64decode(digest))

def connect(path=':memory:'):
    connection=sqlite3.connect(str(path),isolation_level=None,timeout=10)
    connection.row_factory=sqlite3.Row
    connection.execute('PRAGMA foreign_keys=ON')
    connection.execute('PRAGMA recursive_triggers=ON')
    connection.execute('PRAGMA busy_timeout=10000')
    if connection.execute('PRAGMA foreign_keys').fetchone()[0]!=1:
        raise RuntimeError('Foreign key enforcement is required')
    return connection

@contextmanager
def atomic(db):
    db.execute('BEGIN IMMEDIATE')
    try:
        yield db
        db.execute('COMMIT')
    except BaseException:
        db.execute('ROLLBACK')
        raise

def run_sql(db,path):
    for statement in statements(Path(path).read_text()):
        db.execute(statement)

def migrate(db, *, demo=False, target=None):
    paths=sorted((ROOT/'database/migrations').glob('*.sql'))
    target=len(paths) if target is None else target
    version=db.execute('PRAGMA user_version').fetchone()[0]
    if version>target:
        raise ValueError('Database downgrade refused')
    existing={r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name<>'android_metadata'")}
    if existing and 'SchemaMigrations' not in existing:
        raise ValueError('Unversioned legacy database: make a backup and use a reviewed conversion; file left untouched')
    with atomic(db):
        db.execute('CREATE TABLE IF NOT EXISTS SchemaMigrations(Version INTEGER PRIMARY KEY,Name TEXT NOT NULL,Checksum TEXT NOT NULL)')
        for index,path in enumerate(paths,1):
            digest=sha256(path.read_bytes()).hexdigest()
            row=db.execute('SELECT Checksum FROM SchemaMigrations WHERE Version=?',(index,)).fetchone()
            if index<=version:
                if not row or row[0]!=digest:
                    raise ValueError('Applied migration was modified')
            elif index<=target:
                run_sql(db,path)
                db.execute('INSERT INTO SchemaMigrations VALUES(?,?,?)',(index,path.name,digest))
                db.execute(f'PRAGMA user_version={index}')
        if version==0:
            run_sql(db,ROOT/'database/seeds/production.sql')
            if demo:
                run_sql(db,ROOT/'database/seeds/demo.sql')
        mode=db.execute("SELECT SettingValue FROM AppSettings WHERE SettingKey='environment'").fetchone()[0]
        if mode!=('demo' if demo else 'production'):
            raise ValueError('Demo and production databases must use separate files')

class Store:
    def __init__(self, db, user_id=1):
        self.db=db
        self.user_id=user_id

    def authorize(self, permission):
        if not self.db.execute('SELECT 1 FROM UserPermissions WHERE UserId=? AND PermissionCode=?',(self.user_id,permission)).fetchone():
            raise PermissionError(permission)

    def next_id(self,table,column,typ):
        if (table,column) not in (('Trans','TransId'),('Mstndat','VoucherId')):
            raise ValueError('Unsupported document table')
        return self.db.execute(f'SELECT coalesce(max({column}),0)+1 FROM {table} WHERE Typ=?',(typ,)).fetchone()[0]

    def invoice(self,typ,lines, *, doc_id=None,date=None,method='Cash',customer=None,supplier=None,original=None,warehouse=1,cashbox=1,notes=''):
        self.authorize('write')
        date=date or self.db.execute('SELECT StartDate FROM FiscalYears WHERE FiscalYearId=1').fetchone()[0]
        with atomic(self.db):
            doc_id=doc_id or self.next_id('Trans','TransId',typ)
            old=self.db.execute('SELECT Status FROM Trans WHERE TransId=? AND Typ=?',(doc_id,typ)).fetchone()
            if old and old[0]!='Draft':
                raise ValueError('Posted invoice is immutable')
            head={'TransDate':date,'CustomerId':customer,'SupplierId':supplier,'WarehouseId':warehouse,'CurrencyId':1,
                  'PaymentMethod':method,'CashboxId':cashbox if method=='Cash' else None,'Notes':notes,'CreatedBy':self.user_id,
                  'OriginalTransId':original,'OriginalTyp':2 if typ==3 else 1 if typ==4 else None,
                  'Subtotal':0,'Discount':0,'Tax':0,'Total':0}
            if old:
                self.db.execute('DELETE FROM TransDt WHERE TransId=? AND Typ=?',(doc_id,typ))
                self.db.execute('UPDATE Trans SET '+','.join(k+'=?' for k in head)+' WHERE TransId=? AND Typ=?',(*head.values(),doc_id,typ))
            else:
                row={'TransId':doc_id,'Typ':typ,**head}
                self.db.execute('INSERT INTO Trans('+','.join(row)+') VALUES('+','.join('?' for _ in row)+')',tuple(row.values()))
            subtotal=discount=tax=0
            returned={}
            for index,line in enumerate(lines,1):
                gross=(line['qty']*line['price']+500)//1000
                line_discount=line.get('discount',0)
                line_tax=line.get('tax',0)
                if typ in (3,4):
                    original_line=line.get('original_line')
                    orig=self.db.execute('SELECT * FROM TransDt WHERE TransId=? AND Typ=? AND LineNo=?',(original,2 if typ==3 else 1,original_line)).fetchone()
                    if not orig:
                        raise ValueError('Missing original line')
                    previous=self.db.execute("SELECT coalesce(sum(d.Qty),0) FROM TransDt d JOIN Trans t ON t.TransId=d.TransId AND t.Typ=d.Typ WHERE t.OriginalTransId=? AND t.OriginalTyp=? AND t.Status='Posted' AND d.OriginalLineNo=?",(original,2 if typ==3 else 1,original_line)).fetchone()[0]+returned.get(original_line,0)
                    def portion(amount):
                        return (amount*(previous+line['qty'])+orig['Qty']//2)//orig['Qty']-(amount*previous+orig['Qty']//2)//orig['Qty']
                    line_discount=portion(orig['Discount'])
                    gross=portion(orig['GrossAmount']-orig['Discount'])+line_discount
                    line_tax=portion(orig['Tax'])
                    returned[original_line]=returned.get(original_line,0)+line['qty']
                row={'TransId':doc_id,'Typ':typ,'LineNo':index,'ItemId':line['item'],'ItemUnitId':line['unit'],
                     'Qty':line['qty'],'Price':line['price'],'GrossAmount':gross,'Discount':line_discount,'Tax':line_tax,
                     'BatchId':line.get('batch'),'OriginalLineNo':line.get('original_line')}
                self.db.execute('INSERT INTO TransDt('+','.join(row)+') VALUES('+','.join('?' for _ in row)+')',tuple(row.values()))
                subtotal+=gross
                discount+=line_discount
                tax+=line_tax
            self.db.execute('UPDATE Trans SET Subtotal=?,Discount=?,Tax=?,Total=? WHERE TransId=? AND Typ=?',
                            (subtotal,discount,tax,subtotal-discount+tax,doc_id,typ))
            self.db.execute("INSERT INTO AuditLogs(UserId,EntityName,EntityKey,Action) VALUES(?,'Trans',?,'save')",(self.user_id,f'{doc_id}:{typ}'))
        return doc_id

    def voucher(self,typ,lines, *, allocations=(),doc_id=None,date=None,cashbox=1,description=''):
        self.authorize('write')
        date=date or self.db.execute('SELECT StartDate FROM FiscalYears WHERE FiscalYearId=1').fetchone()[0]
        with atomic(self.db):
            doc_id=doc_id or self.next_id('Mstndat','VoucherId',typ)
            amount=sum(x['amount'] for x in lines)
            old=self.db.execute('SELECT Status FROM Mstndat WHERE VoucherId=? AND Typ=?',(doc_id,typ)).fetchone()
            if old:
                self.db.execute('DELETE FROM PaymentAllocation WHERE VoucherId=? AND VoucherTyp=?',(doc_id,typ))
                self.db.execute('DELETE FROM VoucherDt WHERE VoucherId=? AND Typ=?',(doc_id,typ))
                self.db.execute('UPDATE Mstndat SET Amount=?,VoucherDate=?,CashboxId=?,Description=?,CreatedBy=? WHERE VoucherId=? AND Typ=?',(amount,date,cashbox,description,self.user_id,doc_id,typ))
            else:
                self.db.execute('INSERT INTO Mstndat(VoucherId,Typ,VoucherDate,CashboxId,CurrencyId,Amount,Description,CreatedBy) VALUES(?,?,?,?,1,?,?,?)',(doc_id,typ,date,cashbox,amount,description,self.user_id))
            for index,line in enumerate(lines,1):
                self.db.execute('INSERT INTO VoucherDt VALUES(?,?,?,?,?)',(doc_id,typ,index,line['account'],line['amount']))
            for allocation in allocations:
                self.db.execute('INSERT INTO PaymentAllocation(VoucherId,VoucherTyp,TransId,TransTyp,Amount) VALUES(?,?,?,?,?)',(doc_id,typ,allocation['invoice'],allocation['typ'],allocation['amount']))
            self.db.execute("INSERT INTO AuditLogs(UserId,EntityName,EntityKey,Action) VALUES(?,'Mstndat',?,'save')",(self.user_id,f'{doc_id}:{typ}'))
        return doc_id

    def journal(self,lines, *, doc_id=None,date=None,description=''):
        self.authorize('write')
        date=date or self.db.execute('SELECT StartDate FROM FiscalYears WHERE FiscalYearId=1').fetchone()[0]
        with atomic(self.db):
            period=self.db.execute('SELECT PeriodId FROM FiscalPeriods WHERE ? BETWEEN StartDate AND EndDate',(date,)).fetchone()
            if not period:
                raise ValueError('No fiscal period')
            if doc_id:
                self.db.execute('DELETE FROM Yomia WHERE JournalId=?',(doc_id,))
                self.db.execute('UPDATE JournalEntries SET EntryDate=?,PeriodId=?,Description=?,CreatedBy=? WHERE JournalId=? AND Typ=7',(date,period[0],description,self.user_id,doc_id))
            else:
                doc_id=self.db.execute('INSERT INTO JournalEntries(PeriodId,Typ,EntryDate,Description,CreatedBy) VALUES(?,7,?,?,?)',(period[0],date,description,self.user_id)).lastrowid
            for index,line in enumerate(lines,1):
                self.db.execute('INSERT INTO Yomia(JournalId,LineNo,AccountId,Debit,Credit) VALUES(?,?,?,?,?)',(doc_id,index,line['account'],line.get('debit',0),line.get('credit',0)))
            self.db.execute("INSERT INTO AuditLogs(UserId,EntityName,EntityKey,Action) VALUES(?,'JournalEntries',?,'save')",(self.user_id,str(doc_id)))
        return doc_id

    def post(self,family,doc_id,typ=None):
        self.authorize('post')
        table,pk={'invoice':('Trans','TransId'),'voucher':('Mstndat','VoucherId'),'journal':('JournalEntries','JournalId')}[family]
        with atomic(self.db):
            where=f'{pk}=?'+(' AND Typ=?' if typ is not None else ' AND Typ=7')
            params=(doc_id,typ) if typ is not None else (doc_id,)
            count=self.db.execute(f"UPDATE {table} SET CreatedBy=?,Status='Posted' WHERE {where}",(self.user_id,*params)).rowcount
            if count!=1:
                raise ValueError('Document not found')
