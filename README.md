# Vesting Wallet

# Installation

Open a new terminal and:

```console
#install Ganache (if you haven't yet)
npm install ganache-cli --global

#clone repo
git clone https://github.com/trentmc/vesting_wallet.git
cd vesting_wallet

#create a virtual environment
python3 -m venv venv

#activate env
source venv/bin/activate

#install dependencies. Install wheel first to avoid errors.
pip install wheel
pip install -r requirements.txt

#install openzeppelin library, to import from .sol files
brownie pm install OpenZeppelin/openzeppelin-contracts@4.0.0
```

# Compiling

From terminal:
```console
brownie compile
```

It should output:
```text
Brownie v1.17.1 - Python development framework for Ethereum

Compiling contracts...
  Solc version: 0.8.10
  Optimizer: Enabled  Runs: 200
  EVM Version: Istanbul
Generating build data...
 - OpenZeppelin/openzeppelin-contracts@4.0.0/IERC20
 ...
 - VestingWallet
 
Project has been compiled. Build artifacts saved at /home/trentmc/code/vesting_wallet/build/contracts
 ```

# VestingWallet CLI

`vw` is the command-line interface. From the terminal:
```console
#add pwd to bash path
export PATH=$PATH:.

#see vw help
vw
```

You will see something like:
```text
Vesting wallet main help

Usage: vw help|token|fund|wait|release

  vw help - this message
  vw token - create token, for testing
  vw fund - send funds with vesting wallet
  vw mine - force chain to pass time (ganache only)
  vw release - request vesting wallet to release funds

Typical usage flows:
  Run on ganache: token -> fund -> mine -> release
  Run on testnet w test token: token -> fund -> (wait) -> release
  Run on testnet w existing token: fund -> (wait) -> release
  Run on mainnet w test token: token -> fund -> (wait) -> release
  Run on mainnet w existing token: fund -> (wait) -> release
```

Then, use it accordingly:)

# Usage: Running Basic Script

(More for testing)

In terminal:
```console
./scripts/run_vesting_wallet.py
```

# Usage: Running Tests

In terminal:
```console
#run one test
brownie test tests/test_Simpletoken.py::test_transfer

#run tests for one module
brownie test tests/test_Simpletoken.py

#run all tests
brownie test
```

# Usage: Brownie Console

From terminal:
```console
brownie console
```

In brownie console:
```python
>>> t = Simpletoken.deploy("TEST", "Test Token", 18, 100, {'from': accounts[0]})
Transaction sent: 0x3f113379b70d00041068b27733c37c2977354d8c70cb0b30b0af3087fca9c2b8
  Gas price: 0.0 gwei   Gas limit: 6721975   Nonce: 0
  Simpletoken.constructor confirmed   Block: 1   Gas used: 551616 (8.21%)
  Simpletoken deployed at: 0x3194cBDC3dbcd3E11a07892e7bA5c3394048Cc87

>>> t.symbol()                                                                                                                                                                                              
'TEST'
```
