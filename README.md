# Scheduler

# Installation

Open a new terminal and:

```console
#install Ganache (if you haven't yet)
npm install ganache-cli --global

#clone repo
git clone https://github.com/trentmc/scheduler.git
cd scheduler

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
 
Project has been compiled. Build artifacts saved at /home/trentmc/code/scheduler/build/contracts
 ```

# Usage: Running Scheduler Script

In terminal:
```console
./run_vesting_wallet.py
```


# Usage: Running Tests

In terminal:
```console
#run tests
brownie test
```

----

Note: from here on, we show usage in brownie console, py console, etc. While the examples are on (stripped-down) Ocean datatokens, they can be adapted for scheduler too.

# Usage: Brownie Console

From terminal:
```console
brownie console
```

In brownie console:
```python
>>> dt = Datatoken.deploy("DT1", "Datatoken 1", "123.com", 18, 100, {'from': accounts[0]})                                                                                                                 
Transaction sent: 0x9d20d3239d5c8b8a029f037fe573c343efd9361efd4d99307e0f5be7499367ab
  Gas price: 0.0 gwei   Gas limit: 6721975
  Datatoken.constructor confirmed - Block: 1   Gas used: 601010 (8.94%)
  Datatoken deployed at: 0x3194cBDC3dbcd3E11a07892e7bA5c3394048Cc87

>>> dt.blob()                                                                                                                                                                                              
'123.com'
```

# Usage: Python Console

From terminal:
```console
python
```

In Python console:
```python
from scripts import Ocean
config = {
   'network' : 'development',
   'privateKey' : 'cd9ecbe21eb30b7d9dd2808024b4f0da5876e7c7216b28ab6ecb0ccd1d4c76b7',
}
ocean = Ocean.Ocean(config)
account = ocean.account
dt = ocean.createDatatoken('blob_str')
print(dt.address)
```


# Usage: Running Datatoken Script

In terminal:
```console
#run script
export OCEAN_PRIVATE_KEY1=cd9ecbe21eb30b7d9dd2808024b4f0da5876e7c7216b28ab6ecb0ccd1d4c76b7
export OCEAN_PRIVATE_KEY2=cd9ecbe21eb30b7d9dd2808024b4f0da5876e7c7216b28ab6ecb0ccd1d4c76b8
python scripts/dt.py
```

Output is like:
```text
Launching 'ganache-cli --accounts 10 --hardfork istanbul --gasLimit 6721975 --mnemonic brownie --port 8545'...
Transaction sent: 0x3ec84a608396dc5516b2f80cee4af2f2c6ade54f98846fa94db8c999dff5823b
  Gas price: 0.0 gwei   Gas limit: 6721975   Nonce: 0
  Datatoken.constructor confirmed   Block: 1   Gas used: 601154 (8.94%)
  Datatoken deployed at: 0x1678666e6A05a74cfE19f2Bb31eccf306206065C

0x1678666e6A05a74cfE19f2Bb31eccf306206065C
Transaction sent: 0x6640df70ee894b36d22a1cb07a882311fad0d44da581c7dcaa838a75f07c85c1
  Gas price: 0.0 gwei   Gas limit: 6721975   Nonce: 1
  Datatoken.transfer confirmed   Block: 2   Gas used: 50599 (0.75%)

Terminating local RPC client...
```
