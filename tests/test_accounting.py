import json
import sqlite3
import tempfile
import threading
import unittest
from pathlib import Path

from database.runtime import ROOT, Store, atomic, connect, migrate, run_sql, verify_password
from tools.build_assets import bundle

def item(qty=1000,price=1000,**extra):
    return dict(item=101,unit=1011,qty=qty,price=price,**extra)

class AccountingTest(unittest.TestCase):
    def setUp(self):
        self.db=connect()
        migrate(self.db,demo=True)
        self.store=Store(self.db)

    def tearDown(self):
        self.assertEqual(list(self.db.execute('PRAGMA foreign_key_check')),[])
        self.assertEqual(self.db.execute('PRAGMA integrity_check').fetchone()[0],'ok')
        self.db.close()

    def scalar(self,sql,args=()):
        return self.db.execute(sql,args).fetchone()[0]

    def post_invoice(self,typ,lines=None,**kwargs):
        key=self.store.invoice(typ,lines or [item()],**kwargs)
        self.store.post('invoice',key,typ)
        return key

    def stock(self):
        row=self.db.execute('SELECT QtyBase,StockValue FROM StockBalances WHERE WarehouseId=1 AND ItemId=101 AND BatchId IS NULL').fetchone()
        return tuple(row) if row else (0,0)

    def balance(self,account):
        return self.scalar('SELECT Balance FROM AccountBalances WHERE AccountId=?',(account,))

    def test_database_schema_and_seed(self):
        self.assertEqual(self.scalar('PRAGMA foreign_keys'),1)
        self.assertEqual(self.scalar('PRAGMA user_version'),2)
        self.assertEqual(self.scalar("SELECT count(*) FROM sqlite_master WHERE type='table'"),40)
        self.assertGreaterEqual(self.scalar('SELECT count(*) FROM Accounts'),29)
        self.assertEqual(self.scalar('SELECT count(*) FROM DocTyp'),7)
        self.assertEqual(self.scalar("SELECT TypName FROM DocTyp WHERE Typ=5"),'سند صرف')
        self.assertEqual(self.scalar('SELECT count(*) FROM InventoryMovements'),0)

    def test_production_separate_from_demo(self):
        c=connect()
        migrate(c)
        self.assertEqual(c.execute('SELECT count(*) FROM Users').fetchone()[0],0)
        self.assertEqual(c.execute('SELECT count(*) FROM Stk_Item').fetchone()[0],0)
        self.assertEqual(c.execute('SELECT count(*) FROM Customers').fetchone()[0],0)
        with self.assertRaisesRegex(ValueError,'separate'):
            migrate(c,demo=True)
        c.close()

    def test_password_hash_and_permissions(self):
        encoded=self.scalar('SELECT PasswordHash FROM Users WHERE UserId=1')
        self.assertTrue(verify_password('Demo@2026!',encoded))
        self.assertFalse(verify_password('incorrect',encoded))
        self.assertNotIn('Demo@2026!',encoded)
        self.assertEqual(set(r[0] for r in self.db.execute('SELECT PermissionCode FROM UserPermissions WHERE UserId=1')),{'read','write','post'})

    def test_foreign_key_rejects_missing_parent(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO Accounts VALUES(9,'x',999,'Bad','Sub','Debit',1)")

    def test_account_and_item_cycles(self):
        with self.assertRaisesRegex(sqlite3.IntegrityError,'cycle'):
            self.db.execute('UPDATE Accounts SET ParentAccountId=1140 WHERE AccountId=1000')
        self.db.execute("INSERT INTO Stk_Item(ItemId,Code,ParentItemId,ItemName,ItemType) VALUES(2,'G02',1,'Subgroup','Group')")
        with self.assertRaisesRegex(sqlite3.IntegrityError,'cycle'):
            self.db.execute('UPDATE Stk_Item SET ParentItemId=2 WHERE ItemId=1')

    def test_parent_must_be_group(self):
        with self.assertRaisesRegex(sqlite3.IntegrityError,'group'):
            self.db.execute('UPDATE Accounts SET ParentAccountId=1110 WHERE AccountId=1140')

    def test_duplicate_units_and_multiple_base_units(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO Units VALUES(99,'حبة')")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('INSERT INTO Stk_ItemUnit VALUES(999,101,3,1000,1,NULL)')

    def test_money_and_quantity_are_exact_integers(self):
        for line in [item(qty=-1),item(qty=0),item(price=-1),item(qty=1.5),item(price=1.25),item(qty=1000000001)]:
            with self.subTest(line=line), self.assertRaises(sqlite3.IntegrityError):
                self.store.invoice(1,[line])
        self.assertEqual(self.scalar('SELECT count(*) FROM Trans'),0)

    def test_invalid_date_and_type(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.store.invoice(1,[item()],date='2026-02-30')
        with self.assertRaises(sqlite3.IntegrityError):
            self.store.invoice(6,[item()])

    def test_unit_must_belong_to_item(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.store.invoice(1,[dict(item=101,unit=1021,qty=1000,price=100)])

    def test_batch_must_belong_to_item(self):
        self.db.execute("INSERT INTO ItemBatches(BatchId,ItemId,LotNumber) VALUES(1,102,'B1')")
        with self.assertRaises(sqlite3.IntegrityError):
            self.store.invoice(1,[item(batch=1)])

    def test_save_edit_and_search_draft_has_no_effect(self):
        key=self.store.invoice(1,[item()],notes='draft search')
        self.assertEqual(self.stock(),(0,0))
        self.assertEqual(self.balance(1110),0)
        self.store.invoice(1,[item(2000,1200)],doc_id=key,notes='edited')
        self.assertEqual(self.scalar('SELECT Total FROM Trans WHERE TransId=? AND Typ=1',(key,)),2400)
        self.assertEqual(self.scalar("SELECT count(*) FROM Trans WHERE Notes LIKE '%edited%'"),1)
        self.assertEqual(self.scalar('SELECT count(*) FROM JournalEntries'),0)

    def test_cash_purchase_posts_complete_transaction(self):
        self.post_invoice(1,[item(10000,1000,tax=1500,discount=100)])
        self.assertEqual(self.stock(),(10000,9900))
        self.assertEqual(self.balance(1130),9900)
        self.assertEqual(self.balance(1150),1500)
        self.assertEqual(self.balance(1110),-11400)
        self.assertEqual(self.scalar("SELECT count(*) FROM JournalEntries WHERE Status='Posted'"),1)

    def test_cash_sale_includes_cost_of_goods(self):
        self.post_invoice(1,[item(10000,1000)])
        self.post_invoice(2,[item(3000,1500,tax=675,discount=100)])
        self.assertEqual(self.stock(),(7000,7000))
        self.assertEqual(self.balance(4100),-4400)
        self.assertEqual(self.balance(2200),-675)
        self.assertEqual(self.balance(5100),3000)
        self.assertEqual(self.balance(1130),7000)

    def test_credit_purchase_and_sale_party_accounts(self):
        self.post_invoice(1,[item(10000)],method='Credit',supplier=1)
        self.post_invoice(2,[item(2000,1500)],method='Credit',customer=1)
        self.assertEqual(self.balance(2101),-10000)
        self.assertEqual(self.balance(1141),3000)
        self.assertEqual(self.balance(1110),0)

    def test_sales_and_purchase_returns(self):
        p=self.post_invoice(1,[item(10000)])
        sale=self.post_invoice(2,[item(3000,1500)])
        self.post_invoice(3,[item(1000,1500,original_line=1)],original=sale)
        self.post_invoice(4,[item(2000,1000,original_line=1)],original=p)
        self.assertEqual(self.stock(),(6000,6000))
        self.assertEqual(self.balance(4200),1500)
        self.assertEqual(self.balance(5100),2000)
        self.assertEqual(self.balance(1110),-5000)

    def test_return_cannot_exceed_original_or_change_price(self):
        p=self.post_invoice(1,[item(2000)])
        for line in [item(3000,1000,original_line=1),item(1000,900,original_line=1)]:
            r=self.store.invoice(4,[line],original=p)
            with self.assertRaises(sqlite3.IntegrityError):
                self.store.post('invoice',r,4)
        self.assertEqual(self.stock(),(2000,2000))

    def test_repeated_partial_returns_limit(self):
        p=self.post_invoice(1,[item(2000)])
        self.post_invoice(4,[item(1000,1000,original_line=1)],original=p)
        self.post_invoice(4,[item(1000,1000,original_line=1)],original=p)
        self.post_invoice(1,[item(1000,1000)])
        r=self.store.invoice(4,[item(1000,1000,original_line=1)],original=p)
        with self.assertRaisesRegex(sqlite3.IntegrityError,'original quantity'):
            self.store.post('invoice',r,4)
        self.assertEqual(self.stock(),(1000,1000))

    def test_partial_return_reverses_exact_historical_cost_and_tax(self):
        self.post_invoice(1,[item(3000,1,discount=1)])
        s=self.post_invoice(2,[item(3000,4,tax=1)])
        for _ in range(3):
            self.post_invoice(3,[item(1000,4,original_line=1)],original=s)
        self.assertEqual(self.stock(),(3000,2))
        self.assertEqual(self.balance(5100),0)
        self.assertEqual(self.balance(2200),0)
        self.assertEqual(self.balance(4200),12)

    def test_weighted_average_and_purchase_return_variance(self):
        p=self.post_invoice(1,[item(1000,1000)])
        self.post_invoice(1,[item(1000,2000)])
        self.post_invoice(4,[item(1000,1000,original_line=1)],original=p)
        self.assertEqual(self.stock(),(1000,1500))
        self.assertEqual(self.balance(1130),1500)
        self.assertEqual(self.balance(5102),500)

    def test_repeated_item_lines_allocate_rounding_without_residual(self):
        self.post_invoice(1,[item(3000,1,discount=1)])
        self.post_invoice(2,[item(1000,4),item(1000,4),item(1000,4)])
        self.assertEqual(self.stock(),(0,0))
        self.assertEqual(self.balance(5100),2)

    def test_packing_and_fractional_quantities(self):
        self.post_invoice(1,[dict(item=101,unit=1012,qty=3000,price=2400),item(500,100)])
        self.assertEqual(self.stock(),(72500,7250))

    def test_negative_stock_blocked_and_fully_rolled_back(self):
        key=self.store.invoice(2,[item()])
        with self.assertRaisesRegex(sqlite3.IntegrityError,'Insufficient stock'):
            self.store.post('invoice',key,2)
        self.assertEqual(self.scalar('SELECT count(*) FROM InventoryMovements'),0)
        self.assertEqual(self.scalar('SELECT count(*) FROM JournalEntries'),0)
        self.assertEqual(self.scalar("SELECT Status FROM Trans WHERE Typ=2"),'Draft')

    def test_double_post_is_rejected(self):
        key=self.post_invoice(1)
        with self.assertRaisesRegex(sqlite3.IntegrityError,'immutable'):
            self.store.post('invoice',key,1)
        self.assertEqual(self.stock(),(1000,1000))
        self.assertEqual(self.scalar('SELECT count(*) FROM JournalEntries'),1)

    def test_direct_sql_post_is_atomic_and_complete(self):
        key=self.store.invoice(1,[item()])
        self.db.execute("UPDATE Trans SET Status='Posted' WHERE TransId=? AND Typ=1",(key,))
        self.assertEqual(self.scalar('SELECT count(*) FROM InventoryMovements'),1)
        self.assertEqual(self.scalar("SELECT count(*) FROM JournalEntries WHERE Status='Posted'"),1)

    def test_insert_posted_header_cannot_bypass_workflow(self):
        key=self.store.invoice(1,[item()])
        self.db.execute('DELETE FROM TransDt WHERE TransId=? AND Typ=1',(key,))
        with self.assertRaisesRegex(sqlite3.IntegrityError,'requires lines'):
            self.store.post('invoice',key,1)
        with self.assertRaisesRegex(sqlite3.IntegrityError,'draft first'):
            self.db.execute("INSERT INTO JournalEntries(PeriodId,Typ,EntryDate,Status,CreatedBy) SELECT 1,7,StartDate,'Posted',1 FROM FiscalYears WHERE FiscalYearId=1")

    def test_injected_failure_after_stock_and_journal_rolls_everything_back(self):
        key=self.store.invoice(1,[item()])
        self.db.execute("CREATE TRIGGER inject_failure BEFORE INSERT ON AuditLogs WHEN NEW.Action='post' AND NEW.EntityName='Trans' BEGIN SELECT RAISE(ABORT,'injected failure'); END")
        with self.assertRaisesRegex(sqlite3.IntegrityError,'injected failure'):
            self.store.post('invoice',key,1)
        self.assertEqual(self.stock(),(0,0))
        self.assertEqual(self.scalar('SELECT count(*) FROM JournalEntries'),0)
        self.assertEqual(self.scalar('SELECT count(*) FROM InventoryMovements'),0)
        self.assertEqual(self.scalar('SELECT CostAmount FROM TransDt'),0)
        self.assertEqual(self.scalar("SELECT count(*) FROM AuditLogs WHERE Action='post'"),0)
        self.assertEqual(self.scalar('SELECT Status FROM Trans'),'Draft')
        self.db.execute('DROP TRIGGER inject_failure')
        self.store.post('invoice',key,1)

    def test_invoice_totals_cannot_be_forged(self):
        key=self.store.invoice(1,[item()])
        self.db.execute('UPDATE Trans SET Subtotal=999,Total=999')
        with self.assertRaisesRegex(sqlite3.IntegrityError,'totals'):
            self.store.post('invoice',key,1)

    def test_posted_header_lines_movements_and_audit_are_immutable(self):
        self.post_invoice(1)
        for sql in ["UPDATE Trans SET Notes='change'","DELETE FROM Trans","UPDATE TransDt SET Qty=2000",
                    'DELETE FROM TransDt','DELETE FROM InventoryMovements','UPDATE InventoryMovements SET QuantityChange=2',
                    'DELETE FROM JournalEntries','DELETE FROM Yomia','UPDATE Yomia SET Debit=99','DELETE FROM AuditLogs']:
            with self.subTest(sql=sql),self.assertRaises(sqlite3.IntegrityError):
                self.db.execute(sql)

    def test_used_conversion_cannot_change(self):
        self.post_invoice(1)
        with self.assertRaisesRegex(sqlite3.IntegrityError,'locked'):
            self.db.execute('UPDATE Stk_ItemUnit SET PackingQty=2000,IsBase=0 WHERE ItemUnitId=1011')

    def test_journal_balanced_and_unbalanced(self):
        j=self.store.journal([dict(account=1110,debit=5000),dict(account=3100,credit=5000)])
        self.store.post('journal',j)
        self.assertEqual(self.balance(1110),5000)
        unbalanced=self.store.journal([dict(account=1110,debit=100),dict(account=3100,credit=99)])
        with self.assertRaisesRegex(sqlite3.IntegrityError,'balance'):
            self.store.post('journal',unbalanced)
        self.assertEqual(self.balance(1110),5000)

    def test_main_account_or_two_sided_line_cannot_be_used(self):
        for line in [dict(account=1000,debit=100),dict(account=1110,debit=100,credit=100)]:
            with self.assertRaises(sqlite3.IntegrityError):
                self.store.journal([line])

    def test_manual_inventory_account_is_blocked(self):
        j=self.store.journal([dict(account=1130,debit=100),dict(account=3100,credit=100)])
        with self.assertRaisesRegex(sqlite3.IntegrityError,'inventory document'):
            self.store.post('journal',j)

    def test_receipt_and_payment(self):
        for typ,lines in [(6,[dict(account=1141,amount=1000)]),(5,[dict(account=5400,amount=250)])]:
            key=self.store.voucher(typ,lines)
            self.store.post('voucher',key,typ)
        self.assertEqual(self.balance(1110),750)
        self.assertEqual(self.balance(1141),-1000)
        self.assertEqual(self.balance(5400),250)

    def test_receipt_allocated_across_two_invoices(self):
        self.post_invoice(1,[item(10000)])
        a=self.post_invoice(2,[item(2000,1500)],method='Credit',customer=1)
        b=self.post_invoice(2,[item(2000,1500)],method='Credit',customer=1)
        v=self.store.voucher(6,[dict(account=1141,amount=4000)],allocations=[dict(invoice=a,typ=2,amount=3000),dict(invoice=b,typ=2,amount=1000)])
        self.store.post('voucher',v,6)
        self.assertEqual([r[0] for r in self.db.execute('SELECT Outstanding FROM InvoiceOutstanding ORDER BY TransId')],[0,2000])
        self.assertEqual(self.balance(1141),2000)

    def test_payment_allocated_to_purchase(self):
        p=self.post_invoice(1,[item(5000)],method='Credit',supplier=1)
        v=self.store.voucher(5,[dict(account=2101,amount=2000)],allocations=[dict(invoice=p,typ=1,amount=2000)])
        self.store.post('voucher',v,5)
        self.assertEqual(self.balance(2101),-3000)
        self.assertEqual(self.scalar('SELECT Outstanding FROM InvoiceOutstanding'),3000)

    def test_overallocation_wrong_party_and_wrong_direction_rejected(self):
        self.post_invoice(1,[item(10000)])
        sale=self.post_invoice(2,[item(1000,1500)],method='Credit',customer=1)
        for typ,account,amount in [(6,1141,1501),(6,2101,100),(5,1141,100)]:
            with self.subTest(typ=typ,account=account,amount=amount):
                v=self.store.voucher(typ,[dict(account=account,amount=amount)],allocations=[dict(invoice=sale,typ=2,amount=amount)])
                with self.assertRaises(sqlite3.IntegrityError):
                    self.store.post('voucher',v,typ)
        self.assertEqual(self.scalar('SELECT Outstanding FROM InvoiceOutstanding'),1500)

    def test_combined_allocations_cannot_exceed_voucher(self):
        self.post_invoice(1,[item(10000)])
        a=self.post_invoice(2,[item()],method='Credit',customer=1)
        b=self.post_invoice(2,[item()],method='Credit',customer=1)
        v=self.store.voucher(6,[dict(account=1141,amount=1000)],allocations=[dict(invoice=a,typ=2,amount=600),dict(invoice=b,typ=2,amount=600)])
        with self.assertRaisesRegex(sqlite3.IntegrityError,'exceeds voucher'):
            self.store.post('voucher',v,6)

    def test_credit_return_deducts_outstanding_and_cannot_reverse_settled_part(self):
        self.post_invoice(1,[item(10000)])
        sale=self.post_invoice(2,[item(2000,1500)],method='Credit',customer=1)
        self.post_invoice(3,[item(1000,1500,original_line=1)],original=sale,method='Credit',customer=1)
        self.assertEqual(self.scalar('SELECT Outstanding FROM InvoiceOutstanding'),1500)
        v=self.store.voucher(6,[dict(account=1141,amount=1500)],allocations=[dict(invoice=sale,typ=2,amount=1500)])
        self.store.post('voucher',v,6)
        r=self.store.invoice(3,[item(1000,1500,original_line=1)],original=sale,method='Credit',customer=1)
        with self.assertRaisesRegex(sqlite3.IntegrityError,'unpaid'):
            self.store.post('invoice',r,3)

    def test_closed_period_or_year_blocks_posting(self):
        for table in ('FiscalPeriods','FiscalYears'):
            self.db.execute(f"UPDATE {table} SET Status='Closed'")
            key=self.store.invoice(1,[item()])
            with self.assertRaisesRegex(sqlite3.IntegrityError,'open fiscal'):
                self.store.post('invoice',key,1)
            self.db.execute(f"UPDATE {table} SET Status='Open'")

    def test_period_overlap_is_rejected(self):
        with self.assertRaisesRegex(sqlite3.IntegrityError,'Overlapping'):
            self.db.execute('INSERT INTO FiscalPeriods(PeriodId,FiscalYearId,PeriodName,StartDate,EndDate) SELECT 2,1,\'overlap\',StartDate,EndDate FROM FiscalPeriods WHERE PeriodId=1')

    def test_permission_checked_in_business_layer_and_sql(self):
        key=self.store.invoice(1,[item()])
        self.db.execute('DELETE FROM UserRoles WHERE UserId=1')
        self.db.execute('INSERT INTO UserRoles VALUES(1,3)')
        with self.assertRaises(PermissionError):
            self.store.post('invoice',key,1)
        with self.assertRaises(PermissionError):
            self.store.invoice(1,[item()])
        with self.assertRaisesRegex(sqlite3.IntegrityError,'permission'):
            self.db.execute("UPDATE Trans SET Status='Posted'")

    def test_expansion_documents_cannot_be_marked_posted(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO InventoryCounts VALUES(1,1,'2026-01-01','Posted')")

    def test_migrations_upgrade_preserves_data_and_is_idempotent(self):
        c=connect();migrate(c,demo=True,target=1)
        c.execute("INSERT INTO Units VALUES(99,'upgrade test')")
        migrate(c,demo=True);migrate(c,demo=True)
        self.assertEqual(c.execute('SELECT UnitName FROM Units WHERE UnitId=99').fetchone()[0],'upgrade test')
        self.assertEqual(c.execute('SELECT count(*) FROM SchemaMigrations').fetchone()[0],2)
        with self.assertRaisesRegex(ValueError,'downgrade'):
            migrate(c,demo=True,target=1)
        c.close()

    def test_migration_checksum_failure_leaves_existing_data(self):
        self.db.execute("UPDATE SchemaMigrations SET Checksum='corrupt' WHERE Version=1")
        with self.assertRaisesRegex(ValueError,'modified'):
            migrate(self.db,demo=True)
        self.assertEqual(self.scalar('SELECT count(*) FROM DocTyp'),7)

    def test_legacy_database_refused_without_destroying_data(self):
        c=connect()
        c.execute('CREATE TABLE Accounts(id INTEGER PRIMARY KEY)')
        c.execute('INSERT INTO Accounts VALUES(123)')
        with self.assertRaisesRegex(ValueError,'legacy'):
            migrate(c)
        self.assertEqual(c.execute('SELECT id FROM Accounts').fetchone()[0],123)
        c.close()

    def test_standalone_schema_builds_production_database(self):
        c=connect();run_sql(c,ROOT/'database/schema.sql')
        self.assertEqual(c.execute('PRAGMA integrity_check').fetchone()[0],'ok')
        self.assertEqual(c.execute('SELECT count(*) FROM Users').fetchone()[0],0)
        migrate(c)
        c.close()

    def test_flutter_assets_match_sql_exactly(self):
        data=json.loads((ROOT/'app/assets/database.json').read_text())
        for migration in data['migrations']:
            current=bundle(ROOT/'database/migrations'/migration['name'])
            self.assertEqual(current,{k:v for k,v in migration.items() if k!='version'})
        for name,seed in data['seeds'].items():
            self.assertEqual(seed,bundle(ROOT/'database/seeds'/f'{name}.sql'))

    def test_persistence_after_close_and_reopen(self):
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'persistent.db'
            c=connect(path);migrate(c,demo=True)
            s=Store(c);key=s.invoice(1,[item(2000)]);s.post('invoice',key,1);c.close()
            c=connect(path);migrate(c,demo=True)
            self.assertEqual(c.execute('SELECT QtyBase FROM StockBalances').fetchone()[0],2000)
            self.assertEqual(c.execute('PRAGMA foreign_keys').fetchone()[0],1)
            c.close()

    def test_concurrent_posting_has_only_one_financial_effect(self):
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'concurrent.db'
            c=connect(path);migrate(c,demo=True)
            key=Store(c).invoice(1,[item()]);c.close()
            barrier=threading.Barrier(2)
            results=[]
            def worker():
                db=connect(path)
                barrier.wait()
                try:
                    Store(db).post('invoice',key,1);results.append('posted')
                except sqlite3.IntegrityError:
                    results.append('rejected')
                finally:
                    db.close()
            threads=[threading.Thread(target=worker) for _ in range(2)]
            for t in threads:t.start()
            for t in threads:t.join(timeout=15)
            self.assertCountEqual(results,['posted','rejected'])
            c=connect(path)
            self.assertEqual(c.execute('SELECT count(*) FROM JournalEntries').fetchone()[0],1)
            self.assertEqual(c.execute('SELECT QtyBase FROM StockBalances').fetchone()[0],1000)
            c.close()

    def test_original_erd_files_are_preserved_exactly(self):
        import hashlib
        manifest=json.loads((ROOT/'docs/SOURCE_MANIFEST.json').read_text())
        for source in manifest['files']:
            if source['path'].startswith('docs/'):
                data=(ROOT/source['path']).read_bytes()
                self.assertEqual(hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest(),source['blob_sha1'])

    def test_android_internal_metadata_is_not_a_legacy_accounting_database(self):
        c=connect()
        c.execute('CREATE TABLE android_metadata(locale TEXT)')
        c.execute("INSERT INTO android_metadata VALUES('en_US')")
        migrate(c,demo=True)
        self.assertEqual(c.execute('PRAGMA user_version').fetchone()[0],2)
        self.assertEqual(c.execute('SELECT locale FROM android_metadata').fetchone()[0],'en_US')
        c.close()

    def test_typed_journal_foreign_keys_reject_wrong_or_missing_source(self):
        date=self.scalar('SELECT StartDate FROM FiscalYears')
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('INSERT INTO JournalEntries(PeriodId,Typ,InvoiceId,InvoiceTyp,EntryDate,CreatedBy) VALUES(1,1,999,1,?,1)',(date,))
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('INSERT INTO JournalEntries(PeriodId,Typ,VoucherId,VoucherTyp,EntryDate,CreatedBy) VALUES(1,1,999,5,?,1)',(date,))

    def test_draft_line_cannot_be_moved_to_posted_parent(self):
        posted=self.post_invoice(1)
        draft=self.store.invoice(1,[item()])
        with self.assertRaisesRegex(sqlite3.IntegrityError,'draft parent'):
            self.db.execute('UPDATE TransDt SET TransId=?,LineNo=2 WHERE TransId=? AND Typ=1',(posted,draft))

    def test_warehouse_and_batch_balances_are_independent(self):
        self.db.execute("INSERT INTO Warehouses VALUES(2,1,'Second')")
        self.db.execute("INSERT INTO ItemBatches(BatchId,ItemId,LotNumber) VALUES(1,101,'L1'),(2,101,'L2')")
        self.post_invoice(1,[item(2000,batch=1)])
        for warehouse,batch in [(1,2),(2,1)]:
            key=self.store.invoice(2,[item(batch=batch)],warehouse=warehouse)
            with self.assertRaisesRegex(sqlite3.IntegrityError,'Insufficient stock'):
                self.store.post('invoice',key,2)
        self.assertEqual(self.scalar('SELECT QtyBase FROM StockBalances WHERE BatchId=1'),2000)

    def test_foreign_branch_cannot_post(self):
        self.db.execute("INSERT INTO Branches VALUES(2,'Other')")
        self.db.execute("INSERT INTO Warehouses VALUES(2,2,'Other warehouse')")
        key=self.store.invoice(1,[item()],warehouse=2)
        with self.assertRaisesRegex(sqlite3.IntegrityError,'another branch'):
            self.store.post('invoice',key,1)

    def test_failed_migration_rolls_back_version_and_preserves_data(self):
        c=connect();migrate(c,demo=True,target=1)
        c.execute("INSERT INTO Units VALUES(99,'keep')")
        c.set_authorizer(lambda action,*_: sqlite3.SQLITE_DENY if action==sqlite3.SQLITE_CREATE_TRIGGER else sqlite3.SQLITE_OK)
        with self.assertRaises(sqlite3.DatabaseError):
            migrate(c,demo=True)
        c.set_authorizer(None)
        self.assertEqual(c.execute('PRAGMA user_version').fetchone()[0],1)
        self.assertEqual(c.execute('SELECT count(*) FROM SchemaMigrations').fetchone()[0],1)
        self.assertEqual(c.execute('SELECT UnitName FROM Units WHERE UnitId=99').fetchone()[0],'keep')
        migrate(c,demo=True)
        self.assertEqual(c.execute('PRAGMA user_version').fetchone()[0],2)
        c.close()

    def test_inventory_ledger_reconciles_and_all_posted_journals_balance(self):
        self.post_invoice(1,[item(10000,1234,tax=1851)])
        self.post_invoice(2,[item(2500,2000,tax=750)])
        self.assertEqual(self.balance(1130),self.scalar('SELECT sum(StockValue) FROM StockBalances'))
        self.assertEqual(self.scalar('SELECT sum(Balance) FROM AccountBalances'),0)
        self.assertEqual(list(self.db.execute("SELECT j.JournalId FROM JournalEntries j JOIN Yomia y USING(JournalId) WHERE j.Status='Posted' GROUP BY j.JournalId HAVING sum(y.Debit)<>sum(y.Credit)")),[])

if __name__=='__main__':
    unittest.main()
