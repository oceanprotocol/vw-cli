// BigchainDB GmbH and Ocean Protocol contributors
// SPDX-License-Identifier: (Apache-2.0 AND MIT)

pragma solidity ^0.8.0;

import "OpenZeppelin/openzeppelin-contracts@4.7.0/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.0/contracts/access/Ownable.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.0/contracts/security/ReentrancyGuard.sol";

contract Router is Ownable, ReentrancyGuard {
    uint256 private _totalShares;
    mapping(address => uint256) private _totalReleased;
    
    event PayeeAdded(address account, uint256 shares);
    event PaymentReleased(IERC20 indexed token, uint256 amount);
    event PayeeRemoved(address account, uint256 shares);
    event PayeeShareAdjusted(address account, uint256 shares, uint256 oldShares);

    mapping(address => uint256) private _shares;
    mapping(address => mapping(address => uint256)) private _released;
    address[] public _payees;

    constructor(address[] memory payees, uint256[] memory shares_) payable {
        require(payees.length == shares_.length, "Router: payees and shares length mismatch");
        require(payees.length > 0, "Router: no payees");

        for (uint256 i = 0; i < payees.length; i++) {
            _addPayee(payees[i], shares_[i]);
        }
    }

    // ---------------------------- getters ----------------------------
    function shares(address account) public view returns (uint256) {
        return _shares[account];
    }


    function released(address account, address token) public view returns (uint256) {
        return _released[token][account];
    }

    function totalShares() public view returns (uint256) {
        return _totalShares;
    }

    function totalReleased(address token) public view returns (uint256) {
        return _totalReleased[token];
    }
    // ---------------------------- external functions ----------------------------
    function release(IERC20 token) external nonReentrant {
        require(_totalShares > 0, "Router: no shares");
        uint256 balance = token.balanceOf(address(this));
        uint256 total = 0;
        for(uint256 i = 0; i < _payees.length; i++) {
            address payee = _payees[i];
            uint256 payment;
            if (i == _payees.length - 1){
                payment = balance - total;
            } else {
                payment = balance * _shares[payee] / _totalShares;
            }
            if (payment > 0) {
                _released[payee][address(token)] = _released[payee][address(token)] + payment;
                SafeERC20.safeTransfer(token, payee, payment);
                total += payment;
            }
        }
        _totalReleased[address(token)] = _totalReleased[address(token)] + total;
        emit PaymentReleased(token, total);
    }

     function addPayee(address account, uint256 shares_) external onlyOwner {
        _addPayee(account, shares_);
    }

    function removePayee(address account) external onlyOwner {
        _removePayee(account);
    }

    function adjustShare(address account, uint256 shares_) external onlyOwner {
        _adjustShare(account, shares_);
    }


    
    // ---------------------------- private functions ----------------------------

    function _addPayee(address account, uint256 shares_) private {
        require(account != address(0), "Router: account is the zero address");
        require(shares_ > 0, "Router: shares are 0");
        require(_shares[account] == 0, "Router: account already has shares");

        _payees.push(account);
        _shares[account] = shares_;
        _totalShares = _totalShares + shares_;
        emit PayeeAdded(account, shares_);
    }


    function _removePayee(address account) private {
        require(account != address(0), "Router: account is the zero address");
        require(_shares[account] > 0, "Router: account has no shares");

        for (uint256 i = 0; i < _payees.length; i++) {
            if (_payees[i] == account) {
                _payees[i] = _payees[_payees.length - 1];
                _totalShares = _totalShares - _shares[account];
                emit PayeeRemoved(account, _shares[account]);
                _shares[account] = 0;
                _payees.pop();
                break;
            }
        }
    }

    function _adjustShare(address account, uint256 shares_) private {
        require(account != address(0), "Router: account is the zero address");
        require(shares_ > 0, "Router: shares are 0");
        require(_shares[account] > 0, "Router: account has no shares");

        uint256 oldShares = _shares[account];
        _shares[account] = shares_;
        _totalShares = _totalShares - oldShares + shares_;
        emit PayeeShareAdjusted(account, shares_, oldShares);
    }


    //---------------------------- fallback ----------------------------
   
    receive() external payable virtual {
        revert("Router: cannot receive ether");
    }
}