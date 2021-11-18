Note: on 20200526, this code was moved to https://github.com/oceanprotocol/ocean-lib-py. We'll evolve it from there.

Therefore this repo is obsolete. But, keep it around for now, because the oceanprotocol/ocean-lib-py will evolve, and we can use this repo for reference.

----

# ocean-lib-py

Compile, test, and deploy Ocean datatokens with the help of [Brownie](https://eth-brownie.readthedocs.io). Datatokens are ERC20 tokens with an extra 'blob' parameter.

Note: we don't use a Factory contract here. It just deploys the tokens individually.

# Installation

Open a new terminal and:

```console
#install Ganache (if you haven't yet)
npm install ganache-cli --global

#Do a workaround for a bug introduced in Node 17.0.1 in Oct 2021
export NODE_OPTIONS=--openssl-legacy-provider

#clone repo
git clone https://github.com/trentmc/ocean-lib-py.git
cd ocean-lib-py

#create a virtual environment
python3 -m venv venv

#activate env
source venv/bin/activate

#install dependencies. Install wheel first to avoid errors.
pip install wheel
pip install -r requirements.txt
```


# Usage: From Terminal

In terminal:
```console
#set private keys
export OCEAN_PRIVATE_KEY1=cd9ecbe21eb30b7d9dd2808024b4f0da5876e7c7216b28ab6ecb0ccd1d4c76b7
export OCEAN_PRIVATE_KEY2=cd9ecbe21eb30b7d9dd2808024b4f0da5876e7c7216b28ab6ecb0ccd1d4c76b8

#compile
brownie compile

#test
brownie test

#run quickstart
python quickstart.py
```


# Usage: In Brownie Console

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

# Quickstart snippet

## 1. Alice publishes a dataset (= publishes a datatoken contract)


Open a Python terminal and:
```python
from ocean_lib import Ocean
config = {
   'network' : 'development',
   'privateKey' : 'cd9ecbe21eb30b7d9dd2808024b4f0da5876e7c7216b28ab6ecb0ccd1d4c76b7',
}
ocean = Ocean.Ocean(config)
account = ocean.account
dt = ocean.createDatatoken('blob_str')
print(dt.address)
```
