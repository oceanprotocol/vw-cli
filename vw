#!/usr/bin/env python

import brownie
from enforce_typing import enforce_types
import csv
import os
import sys

from util.base18 import toBase18, fromBase18

BROWNIE_PROJECT = brownie.project.load("./", name="MyProject")

NETWORKS = ['development', 'eth_mainnet'] #development = ganache

# ========================================================================
HELP_MAIN = """Vesting wallet

Usage for funder:
  vw new_cliff NETWORK TO_ADDR LOCK_TIME - create new cliff wallet (timelock)
  vw new_lin   NETWORK TO_ADDR VEST_BLOCKS - create new linear-vesting wallet
  vw new_exp   NETWORK TO_ADDR HALF_LIFE - create new exp'l-vesting wallet

  vw transfer NETWORK TO_ADDR TOKEN_ADDR TOKEN_AMT - transfer funds to wallet

Usage for beneficiary:
  vw release NETWORK TOKEN_ADDR WALLET_ADDR - request wallet to release funds

Other tools:
  vw newacct - generate new account
  vw newtoken NETWORK - create token, for testing
  vw mine BLOCKS [TIMEDELTA] - force chain to pass time (ganache only)

  vw acctinfo NETWORK ACCOUNT_ADDR TOKEN_ADDR - info about an account
  vw walletinfo NETWORK WALLET_ADDR [TOKEN_ADDR] - info about a vesting wallet
  vw chaininfo NETWORK - info about a network
  vw help - this message

Transactions are signed with envvar 'VW_PRIVATE_KEY`.
"""

@enforce_types
def do_help():
    print(HELP_MAIN)
    sys.exit(0)

# ========================================================================
@enforce_types
def do_new_cliff():
    HELP = f"""Create new cliff wallet (timelock)

Usage: vw new_cliff NETWORK TO_ADDR LOCK_TIME
  NETWORK -- one of {NETWORKS}
  TO_ADDR -- address of beneficiary
  LOCK_TIME -- Eg '10' (10 seconds) or '63113852' (2 years)
"""
    if len(sys.argv) not in [5]:
        print(HELP); sys.exit(0)

    #extract inputs
    NETWORK = sys.argv[2]
    TO_ADDR = sys.argv[3]
    LOCK_TIME = int(sys.argv[4])
    print(f"Arguments: \nNETWORK = {NETWORK}\n TO_ADDR = {TO_ADDR}" \
          f"\nLOCK_TIME = {LOCK_TIME}")
    
    #main work
    brownie.network.connect(NETWORK)
    start_timestamp = brownie.network.chain[-1].timestamp + 1
    from_account = _getPrivateAccount()
    wallet = BROWNIE_PROJECT.VestingWalletCliff.deploy(
        TO_ADDR, start_timestamp, LOCK_TIME, {"from": from_account})
    print(f"Created new cliff wallet:")
    print(f" address = {wallet.address}")
    print(f" created from account = {from_account.address}")
    print(f" For other vw tools: export WALLET_ADDR={wallet.address}")

# ========================================================================
@enforce_types
def do_new_lin():
    HELP = f"""Create new linear-vesting wallet

Usage: vw new_lin NETWORK TO_ADDR VEST_BLOCKS
  NETWORK -- one of {NETWORKS}
  TO_ADDR -- address of beneficiary
  VEST_BLOCKS -- number of blocks to vest over
"""
    if len(sys.argv) not in [5]:
        print(HELP); sys.exit(0)

    #extract inputs
    NETWORK = sys.argv[2]
    TO_ADDR = sys.argv[3]
    VEST_BLOCKS = int(sys.argv[4])
    print(f"Arguments: \nNETWORK = {NETWORK}\n TO_ADDR = {TO_ADDR}" \
          f"\nVEST_BLOCKS = {VEST_BLOCKS}")
    
    #main work
    brownie.network.connect(NETWORK)
    start_block = len(brownie.network.chain) + 1
    from_account = _getPrivateAccount()
    wallet = BROWNIE_PROJECT.VestingWalletLinear.deploy(
        TO_ADDR, toBase18(start_block), toBase18(VEST_BLOCKS),
        {"from": from_account})
    print(f"Created new linear wallet:")
    print(f" address = { wallet.address}")
    print(f" created from account = {from_account.address}")
    print(f" For other vw tools: export WALLET_ADDR={wallet.address}")
    
# ========================================================================
@enforce_types
def do_new_exp():
    HELP=f"""Create new exponential-vesting wallet

Usage: vw new_exp NETWORK TO_ADDR HALF_LIFE
  NETWORK -- one of {NETWORKS}
  TO_ADDR -- address of beneficiary
  HALF_LIFE -- number of *blocks* for the first 50% to vest
"""
    if len(sys.argv) not in [6]:
        print(HELP); sys.exit(0)

    #extract inputs
    NETWORK = sys.argv[2]
    TO_ADDR = sys.argv[3]
    HALF_LIFE = int(sys.argv[4])
    print(f"Arguments: \nNETWORK = {NETWORK}\n TO_ADDR = {TO_ADDR}" \
          f"\nHALF_LIFE = {HALF_LIFE}")
    
    #main work
    brownie.network.connect(NETWORK)
    start_block = len(brownie.network.chain) + 1
    from_account = _getPrivateAccount()
    print("Need to implement VestingWalletExp.sol. Exiting."); sys.exit(0)
    wallet = BROWNIE_PROJECT.VestingWalletExp.deploy(
        TO_ADDR, toBase18(start_block), toBase18(HALF_LIFE),
        {"from": from_account})
    print(f"Created new exponential wallet:")
    print(f" address = {wallet.address}")
    print(f" created from account = {from_account.address}")
    print(f" For other vw tools: export WALLET_ADDR={wallet.address}")

# ========================================================================
@enforce_types
def do_transfer():
    HELP = f"""Transfer funds to wallet

Usage: vw transfer NETWORK TO_ADDR TOKEN_ADDR TOKEN_AMT 
  NETWORK -- one of {NETWORKS}
  TO_ADDR -- recipient address, e.g. vesting wallet
  TOKEN_ADDR -- address of token being sent
  TOKEN_AMT -- e.g. '1000' (base-18, not wei)

Note: alternative to this, any crypto wallet could be used to transfer funds
"""
    if len(sys.argv) not in [6]:
        print(HELP); sys.exit(0)

    # extract inputs
    NETWORK = sys.argv[2]
    TO_ADDR = sys.argv[3]
    TOKEN_ADDR = sys.argv[4]
    TOKEN_AMT = float(sys.argv[5])
    print(f"Arguments:\nNETWORK = {NETWORK}\nTO_ADDR = {TO_ADDR}"
          f"\nTOKEN_ADDR = {TOKEN_ADDR}\nTOKEN_AMT = {TOKEN_AMT}")
        
    #main work
    brownie.network.connect(NETWORK) 
    chain = brownie.network.chain
    from_account = _getPrivateAccount()
    token = BROWNIE_PROJECT.Simpletoken.at(TOKEN_ADDR)
    token.transfer(TO_ADDR, toBase18(TOKEN_AMT), {"from": from_account})   
    print(f"Sent {TOKEN_AMT} {token.symbol()} to wallet {TO_ADDR}")

# ========================================================================
@enforce_types
def do_release():
    HELP = f"""Request wallet to release funds

Usage: vw release NETWORK TOKEN_ADDR WALLET_ADDR
  NETWORK -- one of {NETWORKS}
  TOKEN_ADDR -- e.g. '0x123..'
  WALLET_ADDR -- vesting wallet, e.g. '0x987...'
"""
    if len(sys.argv) not in [5]:
        print(HELP)
        sys.exit(0)

    # extract inputs
    NETWORK = sys.argv[2]
    TOKEN_ADDR = sys.argv[3]
    WALLET_ADDR = sys.argv[4]

    print(f"Arguments:\nNETWORK = {NETWORK}\nTOKEN_ADDR = {TOKEN_ADDR}"
          f"\nWALLET_ADDR = {WALLET_ADDR}")

    #main work
    brownie.network.connect(NETWORK) 
    accounts = brownie.network.accounts
    from_account = _getPrivateAccount()
    vesting_wallet = BROWNIE_PROJECT.VestingWalletCliff.at(WALLET_ADDR)
    vesting_wallet.release(TOKEN_ADDR, {"from": from_account})
    print("Funds have been released.")

# ========================================================================
@enforce_types
def do_newacct():
    HELP = f"""Generate new account.

Usage: vw newacct
"""
    if len(sys.argv) not in [2]:
        print(HELP)
        sys.exit(0)

    # extract inputs
    assert sys.argv[1] == "newacct"

    #main work
    NETWORK = 'development' #hardcoded bc it's the only one we can force
    brownie.network.connect(NETWORK) 
    account = brownie.network.accounts.add()
    print("Created new account:")
    print(f" address = {account.address}")
    print(f" private_key = {account.private_key}")
    print(f" For other vw tools: export VW_PRIVATE_KEY={account.private_key}")
    
# ========================================================================
@enforce_types
def do_newtoken():
    HELP = f"""Create token, for testing

Usage: vw newtoken NETWORK
  NETWORK -- one of {NETWORKS}
"""
    if len(sys.argv) not in [3]:
        print(HELP)
        sys.exit(0)

    # extract inputs
    NETWORK = sys.argv[2]

    print(f"Arguments:\nNETWORK = {NETWORK}")

    #main work
    brownie.network.connect(NETWORK) 
    accounts = brownie.network.accounts
    from_account = _getPrivateAccount()
    token = BROWNIE_PROJECT.Simpletoken.deploy(
        "TST", "Test Token", 18, 1e21, {"from": from_account})
    print("Created new token:")
    print(f" symbol = {token.symbol()}")
    print(f" address = {token.address}")
    print(f" created from account = {from_account.address}")
    print(f" For other vw tools: export TOKEN_ADDR={token.address}")
    
# ========================================================================
@enforce_types
def do_mine():
    HELP = f"""Force chain to pass time (ganache only)

Usage: vw mine BLOCKS TIMEDELTA
  BLOCKS -- e.g. 3
  TIMEDELTA -- e.g. 100
"""
    if len(sys.argv) not in [4]:
        print(HELP)
        sys.exit(0)

    # extract inputs
    BLOCKS = int(sys.argv[2])
    TIMEDELTA = int(sys.argv[3])
    print(f"Arguments:\nBLOCKS = {BLOCKS}\nTIMEDELTA = {TIMEDELTA}")

    #main work
    NETWORK = 'development' #hardcoded bc it's the only one we can force
    brownie.network.connect(NETWORK) 
    accounts = brownie.network.accounts
    chain = brownie.network.chain
    from_account = _getPrivateAccount()
    chain.mine(blocks=BLOCKS, timedelta=TIMEDELTA)    
    print("Done.")

# ========================================================================
@enforce_types
def do_acctinfo():
    HELP = f"""Info about an account.

Usage: vw acctinfo NETWORK ACCOUNT_ADDR TOKEN_ADDR
  NETWORK -- one of {NETWORKS}
  ACCOUNT_ADDR -- e.g. '0x987...' or '4'. If the latter, uses accounts[i]
  TOKEN_ADDR -- e.g. '0x123..'
"""
    if len(sys.argv) not in [5]:
        print(HELP)
        sys.exit(0)

    # extract inputs
    assert sys.argv[1] == "acctinfo"
    NETWORK = sys.argv[2]
    ACCOUNT_ADDR = sys.argv[3]
    TOKEN_ADDR = sys.argv[4] 

    # do work
    print("Account info:")
    brownie.network.connect(NETWORK)
    if len(str(ACCOUNT_ADDR)) == 1:
        addr_i = int(ACCOUNT_ADDR)
        ACCOUNT_ADDR = brownie.accounts[addr_i]
    print(f"  Address = {ACCOUNT_ADDR}")

    token = B.Simpletoken.at(TOKEN_ADDR)
    balance = token.balanceOf(ACCOUNT_ADDR)
    print(f"  {fromBase18(balance)} {token.symbol()}")

# ========================================================================
@enforce_types
def do_walletinfo():
    HELP = f"""Info about a vesting wallet

Usage: vw walletinfo TYPE NETWORK WALLET_ADDR [TOKEN_ADDR]
  TYPE -- one of cliff|lin|exp
  NETWORK -- one of {NETWORKS}
  WALLET_ADDR -- vesting wallet address
  TOKEN_ADDR -- e.g. '0x123..'
"""
    if len(sys.argv) not in [5,6]:
        print(HELP)
        sys.exit(0)

    # extract inputs
    TYPE = sys.argv[2]
    NETWORK = sys.argv[3]
    WALLET_ADDR = sys.argv[4]
    TOKEN_ADDR = sys.argv[5] if len(sys.argv)==6 else None

    print(f"Arguments:\nNETWORK={NETWORK}" \
          f"\nWALLET_ADDR = {WALLET_ADDR}" \
          f"\nTOKEN_ADDR = {TOKEN_ADDR}")
    if TYPE not in ["cliff", "lin", "exp"]:
        print("Unknown TYPE. Exiting."); sys.exit(0)

    #main work
    brownie.network.connect(NETWORK)
    chain = brownie.network.chain
    if TYPE == "cliff":
        wallet = BROWNIE_PROJECT.VestingWalletCliff.at(WALLET_ADDR)
    elif TYPE == "lin":
        wallet = BROWNIE_PROJECT.VestingWalletLinear.at(WALLET_ADDR)
    elif TYPE == "exp":
        wallet = BROWNIE_PROJECT.VestingWalletExp.at(WALLET_ADDR)
        
    print(f"Vesting wallet info:")
    print(f"  type = {TYPE}")
    print(f"  address = {WALLET_ADDR}")
    print(f"  beneficiary = {wallet.beneficiary()}..")
    
    if TYPE == "cliff":
        print(f"  duration = {wallet.duration()} seconds")
        print(f"  start timestamp = {wallet.start()}")
    elif TYPE == "lin":
        print(f"  duration = {fromBase18(wallet.numBlocksDuration())} blocks")
        print(f"  start block = block {fromBase18(wallet.startBlock())}")
    elif TYPE == "exp":
        print(f"  half life = {fromBase18(wallet.halfLife())} blocks")
        print(f"  start block = block {fromBase18(wallet.start())}")
        
    if TOKEN_ADDR is not None:
        print(f"  For token '{token.symbol()}':")
        token = BROWNIE_PROJECT.Simpletoken.at(TOKEN_ADDR)
        amt_vested = wallet.vestedAmount(token.address, chain[-1].timestamp)
        amt_released = wallet.released(token.address)
        print(f"    amt vested: {fromBase18(amt_vested)} {token.symbol()}")
        print(f"    amt released: {fromBase18(amt_released)} {token.symbol()}")

    print("Some chain info:")
    print(f"  current chain timestamp = {chain[-1].timestamp}")
    print(f"  current chain block = {len(chain)}")

# ========================================================================
@enforce_types
def do_chaininfo():
    HELP = f"""Info about a network

Usage: vw chaininfo NETWORK
  NETWORK -- one of {NETWORKS}
"""
    if len(sys.argv) not in [3]:
        print(HELP)
        sys.exit(0)

    # extract inputs
    NETWORK = sys.argv[2]

    #do work
    brownie.network.connect(NETWORK)
    blocks = len(brownie.network.chain)
    print("\nChain info:")
    print(f"  # blocks: {len(brownie.network.chain)}")
    
# ========================================================================
@enforce_types
def _getPrivateAccount():
    private_key = os.getenv('VW_PRIVATE_KEY')
    account = brownie.network.accounts.add(private_key=private_key)
    print(f"For VW_PRIVATE_KEY, address is: {account.address}")
    return account

# ========================================================================
# main
@enforce_types
def do_main():
    if len(sys.argv) == 1 or sys.argv[1] == "help":
        do_help()

    #usage for funder
    elif sys.argv[1] == "new_cliff":
        do_new_cliff()
    elif sys.argv[1] == "new_lin":
        do_new_lin()
    elif sys.argv[1] == "new_exp":
        do_new_exp()
    elif sys.argv[1] == "transfer":
        do_transfer()

    #usage for beneficiary
    elif sys.argv[1] == "release":
        do_release()

    #other tools
    elif sys.argv[1] == "newacct":
        do_newacct()
    elif sys.argv[1] == "newtoken":
        do_newtoken()
    elif sys.argv[1] == "mine":
        do_mine()
    elif sys.argv[1] == "acctinfo":
        do_acctinfo()
    elif sys.argv[1] == "walletinfo":
        do_walletinfo()
    elif sys.argv[1] == "chaininfo":
        do_chaininfo()
    else:
        do_help()

if __name__ == "__main__":
    do_main()
