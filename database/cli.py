"""python3 -m database.cli init /tmp/accounting_demo.db --demo"""
import argparse
import getpass
import json
from pathlib import Path
from .runtime import atomic, connect, migrate, password_hash

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('command',choices=['init','check'])
    parser.add_argument('path')
    parser.add_argument('--demo',action='store_true')
    parser.add_argument('--admin',help='Create the first production administrator (password is prompted securely)')
    args=parser.parse_args()
    if args.command=='check' and not Path(args.path).is_file():
        parser.error('Database file does not exist')
    db=connect(args.path)
    try:
        if args.command=='init':
            migrate(db,demo=args.demo)
            if args.admin:
                if args.demo:
                    parser.error('--admin is only for production')
                password=getpass.getpass('Administrator password (10+ characters): ')
                if password!=getpass.getpass('Confirm password: '):
                    parser.error('Passwords do not match')
                encoded=password_hash(password)
                with atomic(db):
                    if db.execute('SELECT 1 FROM Users LIMIT 1').fetchone():
                        parser.error('Administrator already exists')
                    key=db.execute('INSERT INTO Users(BranchId,Username,PasswordHash) VALUES(1,?,?)',(args.admin,encoded)).lastrowid
                    db.execute('INSERT INTO UserRoles VALUES(?,1)',(key,))
        integrity=db.execute('PRAGMA integrity_check').fetchone()[0]
        violations=[tuple(r) for r in db.execute('PRAGMA foreign_key_check')]
        print(json.dumps({'sqlite':__import__('sqlite3').sqlite_version,'schema_version':db.execute('PRAGMA user_version').fetchone()[0],
                          'integrity':integrity,'foreign_key_violations':violations,
                          'tables':db.execute("SELECT count(*) FROM sqlite_master WHERE type='table'").fetchone()[0]},indent=2))
        if integrity!='ok' or violations:
            raise SystemExit(1)
    finally:
        db.close()

if __name__=='__main__':
    main()
