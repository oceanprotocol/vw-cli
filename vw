#!/usr/bin/env python

import csv
import os
import sys

import brownie

from util.base18 import toBase18, fromBase18

BROWNIE_PROJECT = brownie.project.load("./", name="MyProject")

NETWORKS = ['development', 'eth_mainnet'] #development = ganache

# ========================================================================
HELP_MAIN = """Vesting wallet

Usage for funder:
  vw new_cliff NETWORK TO_ADDR LOCK_TIME - deploy new cliff wallet (timelock)
  vw new_lin   NETWORK TO_ADDR VEST_BLOCKS - deploy new linear-vesting wallet
  vw new_exp   NETWORK TO_ADDR HALF_LIFE - deploy new exp'l-vesting wallet

  vw fill NETWORK VW_ADDR TOKEN_ADDR TOKEN_AMT - transfer funds to vesting wallet

Usage for beneficiary:
  vw release - request vesting wallet to release funds

Other tools:
  vw token - create token, for testing
  vw mine - force chain to pass time (ganache only)
  vw accountinfo - info about an account
  vw walletinfo - info about a vesting wallet
  vw help - this message

Transactions are signed with envvar 'VW_KEY`.
"""

def show_help():
    print(HELP_MAIN)
    sys.exit(0)

# ========================================================================
def do_new_cliff():
    HELP = f"""Deploy new cliff wallet (timelock)

Usage: vw new_cliff NETWORK TO_ADDR LOCK_TIME
  NETWORK -- one of {NETWORKS}
  TO_ADDR -- address of beneficiary
  LOCK_TIME -- Eg '10' (10 seconds) or '63113852' (2 years)
"""
    if len(sys.argv) not in [6]:
        print(HELP); sys.exit(0)

    #extract inputs
    assert sys.argv[1] == "new_cliff"
    NETWORK = sys.argv[2]
    TO_ADDR = sys.argv[3]
    LOCK_TIME = int(sys.argv[4])
    print(f"Arguments: \nNETWORK = {NETWORK}\n TO_ADDR = {TO_ADDR}" \
          f"\nLOCK_TIME = {LOCK_TIME}")
    
    #main work
    brownie.network.connect(NETWORK)
    start_timestamp = brownie.network.chain[-1].timestamp + 1
    from_account = _getPrivateAccount()
    vw = BROWNIE_PROJECT.VestingWalletCliff.deploy(
        TO_ADDR, start_timestamp, LOCK_TIME, {"from": from_account})
    print(f"Deployed wallet deployed at address: {vw.address}")

# ========================================================================
def do_new_lin():
    HELP = f"""Deploy new linear-vesting wallet

Usage: vw new_lin NETWORK TO_ADDR VEST_BLOCKS
  NETWORK -- one of {NETWORKS}
  TO_ADDR -- address of beneficiary
  VEST_BLOCKS -- number of blocks to vest over
"""
    if len(sys.argv) not in [6]:
        print(HELP); sys.exit(0)

    #extract inputs
    assert sys.argv[1] == "new_lin"
    NETWORK = sys.argv[2]
    TO_ADDR = sys.argv[3]
    VEST_BLOCKS = int(sys.argv[4])
    print(f"Arguments: \nNETWORK = {NETWORK}\n TO_ADDR = {TO_ADDR}" \
          f"\nVEST_BLOCKS = {VEST_BLOCKS}")
    
    #main work
    brownie.network.connect(NETWORK)
    start_block = len(brownie.network.chain) + 1
    from_account = _getPrivateAccount()
    vw = BROWNIE_PROJECT.VestingWalletLinear.deploy(
        TO_ADDR, toBase18(start_block), toBase18(VEST_BLOCKS),
        {"from": from_account})
    print(f"Deployed wallet deployed at address: {vw.address}")

    
# ========================================================================
def do_new_exp():
    HELP=f"""Deploy new exponential-vesting wallet

Usage: vw new_exp NETWORK TO_ADDR HALF_LIFE
  NETWORK -- one of {NETWORKS}
  TO_ADDR -- address of beneficiary
  HALF_LIFE -- number of *blocks* for the first 50% to vest
"""
    if len(sys.argv) not in [6]:
        print(HELP); sys.exit(0)
    raise NotImplementedError()

# ========================================================================
def do_fill():
    HELP = f"""Transfer funds to vesting wallet

Usage: vw fill NETWORK VW_ADDR TOKEN_ADDR TOKEN_AMT 
  NETWORK -- one of {NETWORKS}
  VW_ADDR -- address of vesting wallet
  TOKEN_ADDR -- address of token being sent
  TOKEN_AMT -- e.g. '1000' (base-18, not wei)

Note: alternative to this, any crypto wallet could be used to transfer funds
"""
    if len(sys.argv) not in [7]:
        print(HELP); sys.exit(0)

    # extract inputs
    assert sys.argv[1] == "fill"
    NETWORK = sys.argv[2]
    VW_ADDR = sys.argv[3]
    TOKEN_ADDR = sys.argv[4]
    TOKEN_AMT = float(sys.argv[6])
    print(f"Arguments:\nNETWORK = {NETWORK}\nVW_ADDR = {VW_ADDR}"
          f"\nTOKEN_ADDR = {TOKEN_ADDR}\nTOKEN_AMT = {TOKEN_AMT}")
        
    #main work
    brownie.network.connect(NETWORK) 
    chain = brownie.network.chain
    from_account = _getPrivateAccount()
    token = BROWNIE_PROJECT.Simpletoken.at(TOKEN_ADDR)
    vw = BROWNIE_PROJECT.VestingWalletCliff.at(VW_ADDR)
    token.transfer(vw, toBase18(TOKEN_AMT), {"from": from_account})
    print(f"Sent {TOKEN_AMT} {token.symbol} to wallet {VW_ADDR}")

# ========================================================================
def do_release():
    HELP = f"""Request vesting wallet to release funds

Usage: vw release NETWORK TOKEN_ADDR WALLET_ADDR
  NETWORK -- one of {NETWORKS}
  TOKEN_ADDR -- e.g. '0x123..'
  WALLET_ADDR -- vesting wallet, e.g. '0x987...'
"""
    if len(sys.argv) not in [5]:
        print(HELP)
        sys.exit(0)

    # extract inputs
    assert sys.argv[1] == "release"
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
def do_token():
    HELP = f"""Create token, for testing

Usage: vw token NETWORK
  NETWORK -- one of {NETWORKS}
"""
    if len(sys.argv) not in [3]:
        print(HELP)
        sys.exit(0)

    # extract inputs
    assert sys.argv[1] == "token"
    NETWORK = sys.argv[2]

    print(f"Arguments:\nNETWORK = {NETWORK}")

    #main work
    brownie.network.connect(NETWORK) 
    accounts = brownie.network.accounts
    from_account = _getPrivateAccount()
    token = BROWNIE_PROJECT.Simpletoken.deploy(
        "TST", "Test Token", 18, 1e21, {"from": from_account})
    print(f"Token '{token.symbol()}' deployed at address: {token.address}")
    
# ========================================================================
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
    assert sys.argv[1] == "mine"
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
def show_accountinfo():
    HELP = f"""Info about an account

Usage: vw accountinfo NETWORK TOKEN_ADDR ACCOUNT_ADDR
  NETWORK -- one of {NETWORKS}
  TOKEN_ADDR -- e.g. '0x123..'
  ACCOUNT_ADDR -- account address, e.g. '0x987...'
"""
    if len(sys.argv) not in [5]:
        print(HELP)
        sys.exit(0)

    # extract inputs
    assert sys.argv[1] == "accountinfo"
    NETWORK = sys.argv[2]
    TOKEN_ADDR = sys.argv[3]
    ACCOUNT_ADDR = sys.argv[4]

    print(f"Arguments:\nNETWORK = {NETWORK}\nTOKEN_ADDR = {TOKEN_ADDR}"
          f"\nACCOUNT_ADDR = {ACCOUNT_ADDR}"
    )

    #main work
    brownie.network.connect(NETWORK)
    token = BROWNIE_PROJECT.Simpletoken.at(TOKEN_ADDR)
    balance = token.balanceOf(ACCOUNT_ADDR)
    print(f"For account {ACCOUNT_ADDR[:5]}.., token '{token.symbol()}':")
    print(f"  balance of token : {fromBase18(balance)} {token.symbol()}")

# ========================================================================
def show_walletinfo():
    HELP = f"""Info about a vesting wallet

Usage: vw walletinfo NETWORK TOKEN_ADDR WALLET_ADDR
  NETWORK -- one of {NETWORKS}
  TOKEN_ADDR -- e.g. '0x123..'
  WALLET_ADDR -- vesting wallet address
"""
    if len(sys.argv) not in [5]:
        print(HELP)
        sys.exit(0)

    # extract inputs
    assert sys.argv[1] == "walletinfo"
    NETWORK = sys.argv[2]
    TOKEN_ADDR = sys.argv[3]
    WALLET_ADDR = sys.argv[4]

    print(f"Arguments:\nNETWORK={NETWORK}\nTOKEN_ADDR = {TOKEN_ADDR}"
          f"\nWALLET_ADDR = {WALLET_ADDR}")

    #main work
    brownie.network.connect(NETWORK)
    chain = brownie.network.chain
    token = BROWNIE_PROJECT.Simpletoken.at(TOKEN_ADDR)
    wallet = BROWNIE_PROJECT.VestingWalletCliff.at(WALLET_ADDR)
    amt_vested = wallet.vestedAmount(token.address, chain[-1].timestamp)
    amt_released = wallet.released(token.address)
    print(f"For vesting wallet {WALLET_ADDR[:5]}.., token '{token.symbol()}':")
    print(f"  beneficiary: {wallet.beneficiary()[:5]}..")
    print(f"  start: {wallet.start()} (compare to current chain time of {chain[-1].timestamp})")
    print(f"  duration: {wallet.duration()} s")
    print(f"  amt vested: {fromBase18(amt_vested)} {token.symbol()}")
    print(f"  amt released: {fromBase18(amt_released)} {token.symbol()}")

# ========================================================================
def _getPrivateAccount():
    private_key = os.getenv('VW_KEY')
    account = brownie.network.accounts.add(private_key=private_key)
    print(f"For private key VW_KEY, address is: {account.address}")
    return account

# ========================================================================
# main
def do_main():
    if len(sys.argv) == 1 or sys.argv[1] == "help":
        show_help()

    #usage for funder
    elif sys.argv[1] == "new_cliff":
        do_new_cliff()
    elif sys.argv[1] == "new_lin":
        do_new_lin()
    elif sys.argv[1] == "new_exp":
        do_new_exp()
    elif sys.argv[1] == "fill":
        do_fill()

    #usage for beneficiary
    elif sys.argv[1] == "release":
        do_release()

    #other tools
    elif sys.argv[1] == "token":
        do_token()
    elif sys.argv[1] == "mine":
        do_mine()
    elif sys.argv[1] == "accountinfo":
        show_accountinfo()
    elif sys.argv[1] == "walletinfo":
        show_walletinfo()
    else:
        show_help()

if __name__ == "__main__":
    do_main()
