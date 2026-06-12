// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title CryptoLock
 * @dev CodeAlpha Internship - Task 4
 * @notice Personal Portfolio — users deposit ETH with a time-lock and can only
 *         withdraw after the lock period has passed.
 */
contract CryptoLock {

    // ──────────────────────────────────────────────
    // Data Structures
    // ──────────────────────────────────────────────

    struct Deposit {
        uint256 amount;       // Amount of ETH locked (in wei)
        uint256 unlockTime;   // Unix timestamp after which withdrawal is allowed
        bool    exists;       // Guard to distinguish empty structs
    }

    // ──────────────────────────────────────────────
    // State Variables
    // ──────────────────────────────────────────────

    // userAddress => Deposit
    mapping(address => Deposit) public deposits;

    // ──────────────────────────────────────────────
    // Events
    // ──────────────────────────────────────────────

    event Deposited(
        address indexed user,
        uint256 amount,
        uint256 unlockTime
    );

    event Withdrawn(
        address indexed user,
        uint256 amount
    );

    event TopUp(
        address indexed user,
        uint256 addedAmount,
        uint256 newTotal
    );

    // ──────────────────────────────────────────────
    // Core Functions
    // ──────────────────────────────────────────────

    /**
     * @dev Deposit Ether with a time-lock
     * @param _lockDurationSeconds Number of seconds to lock the deposit
     * @notice Each address can hold only one active deposit at a time
     */
    function deposit(uint256 _lockDurationSeconds) external payable {
        require(msg.value > 0, "Must deposit some Ether");
        require(_lockDurationSeconds > 0, "Lock duration must be greater than zero");

        // If the user already has an active deposit, top it up
        if (deposits[msg.sender].exists && deposits[msg.sender].amount > 0) {
            deposits[msg.sender].amount += msg.value;

            // Extend the lock if the new duration is longer
            uint256 newUnlockTime = block.timestamp + _lockDurationSeconds;
            if (newUnlockTime > deposits[msg.sender].unlockTime) {
                deposits[msg.sender].unlockTime = newUnlockTime;
            }

            emit TopUp(msg.sender, msg.value, deposits[msg.sender].amount);
        } else {
            // Fresh deposit
            uint256 unlockTime = block.timestamp + _lockDurationSeconds;

            deposits[msg.sender] = Deposit({
                amount:     msg.value,
                unlockTime: unlockTime,
                exists:     true
            });

            emit Deposited(msg.sender, msg.value, unlockTime);
        }
    }

    /**
     * @dev Withdraw the deposited Ether after the lock period has passed
     * @notice Reverts if the lock time has NOT yet passed (enforces time-lock)
     */
    function withdraw() external {
        Deposit storage userDeposit = deposits[msg.sender];

        require(userDeposit.exists, "No deposit found for this address");
        require(userDeposit.amount > 0, "Nothing to withdraw");

        // ── TIME-LOCK CHECK ──────────────────────────────────────────────
        require(
            block.timestamp >= userDeposit.unlockTime,
            "Funds are still locked — please wait until the unlock time"
        );
        // ────────────────────────────────────────────────────────────────

        uint256 amountToSend = userDeposit.amount;

        // Reset storage before transfer (Checks-Effects-Interactions pattern)
        userDeposit.amount     = 0;
        userDeposit.unlockTime = 0;
        userDeposit.exists     = false;

        (bool success, ) = payable(msg.sender).call{value: amountToSend}("");
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, amountToSend);
    }

    // ──────────────────────────────────────────────
    // View Functions
    // ──────────────────────────────────────────────

    /**
     * @dev Returns deposit info for the calling address
     * @return amount        Locked ETH in wei
     * @return unlockTime    Unix timestamp of unlock
     * @return timeRemaining Seconds remaining until unlock (0 if already unlocked)
     * @return isLocked      True if the deposit is still locked
     */
    function getMyDeposit()
        external
        view
        returns (
            uint256 amount,
            uint256 unlockTime,
            uint256 timeRemaining,
            bool    isLocked
        )
    {
        Deposit storage d = deposits[msg.sender];
        require(d.exists, "No deposit found for this address");

        uint256 remaining = 0;
        bool locked = false;

        if (block.timestamp < d.unlockTime) {
            remaining = d.unlockTime - block.timestamp;
            locked = true;
        }

        return (d.amount, d.unlockTime, remaining, locked);
    }

    /**
     * @dev Returns deposit info for any address (public view)
     * @param _user The address to query
     */
    function getDepositOf(address _user)
        external
        view
        returns (
            uint256 amount,
            uint256 unlockTime,
            bool    isLocked
        )
    {
        Deposit storage d = deposits[_user];
        return (
            d.amount,
            d.unlockTime,
            block.timestamp < d.unlockTime
        );
    }

    /**
     * @dev Returns the total ETH held in this contract
     */
    function getTotalLocked() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Returns the current block timestamp — useful for debugging in Remix
     */
    function getCurrentTime() external view returns (uint256) {
        return block.timestamp;
    }
}
