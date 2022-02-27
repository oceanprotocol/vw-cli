#!/usr/bin/env python

import os
import sys

import brownie

from util.base18 import toBase18

BROWNIE_PROJECT = brownie.project.load("./", name="MyProject")

NETWORKS = ['development', 'eth_mainnet'] #development = ganache

# ========================================================================
HELP_MAIN = """
Vesting wallet main help

Usage: vw help|token|fund|mine|release|balance

  vw help - this message
  vw token - create token, for testing
  vw fund - send funds with vesting wallet
  vw mine - force chain to pass time (ganache only)
  vw release - request vesting wallet to release funds
  vw balance - view a token balance 

Typical usage flows:
  Run on ganache: token -> fund -> mine -> release
  Run on testnet w test token: token -> fund -> (wait) -> release
  Run on testnet w existing token: fund -> (wait) -> release
  Run on mainnet w test token: token -> fund -> (wait) -> release
  Run on mainnet w existing token: fund -> (wait) -> release
"""
def do_help():
    print(HELP_MAIN)
    sys.exit(0)


# ========================================================================
def do_token():
    HELP_TOKEN = f"""
    Vesting wallet create test token

    Usage: vw token NETWORK

     NETWORK -- one of {NETWORKS}
    """
    if len(sys.argv) not in [3]:
        print(HELP_TOKEN)
        sys.exit(0)

    # extract inputs
    assert sys.argv[1] == "token"
    NETWORK = sys.argv[2]

    print(f"Arguments: NETWORK={NETWORK}")

    #error handling
    if NETWORK not in NETWORKS:
        print(f"Unknown network '{NETWORK}', exiting.")
        sys.exit(0)

    #brownie setup
    brownie.network.connect(NETWORK) 
    accounts = brownie.network.accounts
    chain = brownie.network.chain
    from_account = accounts[0] #FIXME for non-ganache

    #deploy wallet
    token = BROWNIE_PROJECT.Simpletoken.deploy(
        "TST", "Test Token", 18, 1e21, {"from": from_account}
    )
    print(f"Token '{token.symbol()}' deployed at address: {token.address}")
    
# ========================================================================
def do_fund():
    HELP_FUND = f"""
    Vesting wallet - send funds with vesting wallet

    Usage: vw fund NETWORK AMT TOKEN_ADDR LOCK_TIME TO_ADDR

     NETWORK -- one of {NETWORKS}
     AMT -- e.g. '1000' (base-18, not wei)
     TOKEN_ADDR -- address of token being sent. Eg 0x967da4048cd07ab37855c090aaf366e4ce1b9f48 for OCEAN on eth mainnet
     LOCK_TIME -- Eg '10' (10 seconds) or '63113852' (2 years)
     TO_ADDR -- address of beneficiary
    """

    if len(sys.argv) not in [7]:
        print(HELP_FUND)
        sys.exit(0)

    # extract inputs
    assert sys.argv[1] == "fund"
    NETWORK = sys.argv[2]
    AMT = float(sys.argv[3])
    TOKEN_ADDR = sys.argv[4]
    LOCK_TIME = int(sys.argv[5])
    TO_ADDR = sys.argv[6]
    print(
        f"Arguments: NETWORK={NETWORK}, AMT={AMT}, TOKEN_ADDR={TOKEN_ADDR}"
        f", LOCK_TIME={LOCK_TIME}, TO_ADDR={TO_ADDR}"
    )

    #error handling
    if NETWORK not in NETWORKS:
        print(f"Unknown network '{NETWORK}', exiting.")
        sys.exit(0)

    #brownie setup
    brownie.network.connect(NETWORK) 
    accounts = brownie.network.accounts
    chain = brownie.network.chain
    from_account = accounts[0] #FIXME for non-ganache

    #grab token
    token = BROWNIE_PROJECT.Simpletoken.at(TOKEN_ADDR)
    print(f"Token symbol: {token.symbol()}")

    #deploy vesting wallet
    print("Deploy vesting wallet...")
    start_timestamp = chain[-1].timestamp + 5  # magic number
    vesting_wallet = BROWNIE_PROJECT.VestingWallet.deploy(
        TO_ADDR, start_timestamp, LOCK_TIME, {"from": from_account}
    )
    print(f"Vesting wallet address: {vesting_wallet.address}")

    #send tokens to vesting wallet
    print("Fund vesting wallet...")
    token.transfer(vesting_wallet, toBase18(AMT), {"from": from_account})

    print("Done.")


# ========================================================================
def do_mine():
    HELP_MINE = f"""
    Vesting wallet - force chain to pass time (ganache only)

    Usage: vw mine BLOCKS TIMEDELTA

     BLOCKS -- e.g. 3
     TIMEDELTA -- e.g. 100
    """
    if len(sys.argv) not in [4]:
        print(HELP_MINE)
        sys.exit(0)

    # extract inputs
    assert sys.argv[1] == "mine"
    BLOCKS = int(sys.argv[2])
    TIMEDELTA = int(sys.argv[3])

    print(f"Arguments: BLOCKS={BLOCKS}, TIMEDELTA={TIMEDELTA}")

    #brownie setup
    NETWORK = 'development' #hardcoded bc it's the only one we can force
    brownie.network.connect(NETWORK) 
    accounts = brownie.network.accounts
    chain = brownie.network.chain
    from_account = accounts[0] #FIXME for non-ganache

    #make time pass
    chain.mine(blocks=BLOCKS, timedelta=TIMEDELTA)
    
    print("Done.")

# ========================================================================
def do_release():
    HELP_RELEASE = f"""
    Vesting wallet - request vesting wallet to release funds

    Usage: vw release NETWORK WALLET_ADDR TOKEN_ADDR

     NETWORK -- one of {NETWORKS}
     WALLET_ADDR -- vesting wallet, e.g. '0x987...'
     TOKEN_ADDR -- e.g. '0x123..'
    """
    if len(sys.argv) not in [5]:
        print(HELP_RELEASE)
        sys.exit(0)

    # extract inputs
    assert sys.argv[1] == "release"
    NETWORK = sys.argv[2]
    WALLET_ADDR = sys.argv[3]
    TOKEN_ADDR = sys.argv[4]

    print(f"Arguments: NETWORK={NETWORK}, WALLET_ADDR={WALLET_ADDR}"
          f", TOKEN_ADDR={TOKEN_ADDR}"
    )

    #brownie setup
    brownie.network.connect(NETWORK) 
    accounts = brownie.network.accounts
    chain = brownie.network.chain
    from_account = accounts[0] #FIXME for non-ganache

    #release the token
    vesting_wallet = BROWNIE_PROJECT.VestingWallet.at(WALLET_ADDR)
    vesting_wallet.release(TOKEN_ADDR, {"from": from_account})
    
    print("Funds have been released.")

# ========================================================================
def do_balance():
    HELP_BALANCE = f"""
    Vesting wallet - see balance of a token for an account  

    Usage: vw balance NETWORK TOKEN_ADDR ACCOUNT_ADDR

     NETWORK -- one of {NETWORKS}
     ACCOUNT_ADDR -- account address, e.g. '0x987...'
     TOKEN_ADDR -- e.g. '0x123..'
    """
    if len(sys.argv) not in [5]:
        print(HELP_BALANCE)
        sys.exit(0)

    # extract inputs
    assert sys.argv[1] == "balance"
    NETWORK = sys.argv[2]
    TOKEN_ADDR = sys.argv[3]
    ACCOUNT_ADDR = sys.argv[4]

    print(f"Arguments: NETWORK={NETWORK}, TOKEN_ADDR={TOKEN_ADDR}"
          f", ACCOUNT_ADDR={ACCOUNT_ADDR}"
    )

    #brownie setup
    brownie.network.connect(NETWORK) 
    accounts = brownie.network.accounts
    chain = brownie.network.chain

    #release the token
    token = BROWNIE_PROJECT.Simpletoken.at(TOKEN_ADDR)
    print(f"Balance of token '{token.symbol()}' at address {ACCOUNT_ADDR[:5]}..: {token.balanceOf(ACCOUNT_ADDR)}")
    
# ========================================================================
# main
def do_main():
    if len(sys.argv) == 1 or sys.argv[1] == "help":
        do_help()

    elif sys.argv[1] == "token":
        do_token()
    elif sys.argv[1] == "fund":
        do_fund()
    elif sys.argv[1] == "mine":
        do_mine()
    elif sys.argv[1] == "release":
        do_release()
    elif sys.argv[1] == "balance":
        do_balance()
    else:
        do_help()

if __name__ == "__main__":
    do_main()
