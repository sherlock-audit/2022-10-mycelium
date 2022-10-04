// SPDX-License-Identifier: CC-BY-NC-ND-4.0
pragma solidity ^0.8.9;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../lib/openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import "../lib/solmate/src/utils/FixedPointMathLib.sol";
import "./plugins/IPlugin.sol";
import "./interfaces/IERC677.sol";

/**
 * @title Interest bearing ERC20 token for LINK staked to Mycelium's node
 *
 * myLINK balances are dynamic. They represent the holder's share in the total amount of
 * LINK controlled by the Vault. An account's balance is calculated as:
 *
 *      shares[account] * totalSupply() / totalShares()
 *
 * Mints, transfers, and burns operate on the equivalent number of shares, rather than the balance
 * directly. This allows the balance to change over time without requiring an infeasible number of
 * storage updates.
 *
 * Conversions between myLINK and shares will not always be exact due to rounding errors. For example,
 * if there are 100 shares and 200 myLINK in the Vault, the smallest possible transfer is 2 myLINK.
 */

contract Vault is IERC20, IERC20Metadata, IERC677Receiver, UUPSUpgradeable, Initializable {
    using FixedPointMathLib for uint256;

    /**
     * @notice Address with owner privileges
     * @dev Set in the initializer
     */
    address public owner;

    /// @notice The number of decimals the token uses
    /// @dev This should be the same as the LINK token
    uint8 public decimals;

    /// @notice The address of the LINK token
    address public LINK;

    /// @notice The maximum amount of LINK that can be deposited into the Vault
    /// @dev This is required to prevent integer overflow errors in the myLINK balance calculations
    uint256 public MAX_CAPACITY;

    /// @notice The initial number of shares per LINK deposited
    uint256 public STARTING_SHARES_PER_LINK;

    /**
     * @dev myLINK balances are dynamic and are determined by the total amount of LINK controlled by
     * the Vault and the user's portion of the total shares
     */
    uint256 public totalShares;
    mapping(address => uint256) public shares;

    /**
     * @dev Plugins earn yield for the LINK in the vault. They have a capacity limit and are indexed by priority.
     * LINK is allocated to plugins with lower priority number first, and removed in reverse order.
     * So plugins[0] should fill up first and plugins[pluginCount - 1] should be emptied first.
     */
    uint256 public pluginCount;
    mapping(uint256 => address) public plugins;

    /// @notice The allowed amount of myLINK a spender can transfer on behalf of the owner
    /// @dev allowances are denoted in tokens, not shares
    mapping(address => mapping(address => uint256)) public allowance;

    /**
     * @notice A deposit to the vault
     *
     * @param from The account that deposited the LINK
     * @param amount The amount of LINK deposited
     */
    event Deposit(address indexed from, uint256 amount);

    /**
     * @notice A withdrawal from the vault
     *
     * @param to The account that received the LINK
     * @param amount The amount of LINK withdrawn
     */
    event Withdraw(address indexed to, uint256 amount);

    /**
     * @notice A plugin was added to the vault
     *
     * @param plugin The address of the plugin contract
     * @param index The priority index of the plugin
     */
    event PluginAdded(address indexed plugin, uint256 index);

    /**
     * @notice A plugin was removed from the vault
     *
     * @param plugin The address of the plugin contract
     */
    event PluginRemoved(address indexed plugin);

    /**
     * @notice The owner of the vault was changed
     *
     * @param previousOwner The previous owner of the vault
     * @param newOwner The new owner of the vault
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function initialize(
        address _LINK,
        address _owner,
        uint256 _capacity,
        uint256 _startingSharesPerLink
    ) public initializer {
        LINK = _LINK;
        decimals = IERC20Metadata(_LINK).decimals();
        owner = _owner;
        MAX_CAPACITY = _capacity;
        STARTING_SHARES_PER_LINK = _startingSharesPerLink;
    }

    /****************************************** USER METHODS ******************************************/

    /**
     * @notice Deposits LINK into the vault and mints shares of myLINK of the same value
     *
     * @param _amount The amount of LINK to deposit
     *
     * Emits a {Deposit} event.
     */
    function deposit(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(_amount <= availableForDeposit(), "Amount exceeds available capacity");

        uint256 newShares = convertToShares(_amount);
        _mintShares(msg.sender, newShares);

        IERC20(LINK).transferFrom(msg.sender, address(this), _amount);
        _distributeToPlugins();

        emit Deposit(msg.sender, _amount);
    }

    /**
     * @notice Redeems shares of myLINK for LINK
     * @dev Pulls the LINK from the plugins before burning the shares
     *
     * @param _amount The amount of myLINK to redeem (denominated in tokens, not shares)
     *
     * Emits a {Withdraw} event.
     */

    function withdraw(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(_amount <= balanceOf(msg.sender), "Amount exceeds balance");

        _ensureLinkAmount(_amount);

        _burnShares(msg.sender, convertToShares(_amount));

        IERC20(LINK).transfer(msg.sender, _amount);

        emit Withdraw(msg.sender, _amount);
    }

    /**
     * @notice Redeems all shares of myLINK for LINK
     * @dev There is often a small amount of shares remainining when using the `withdraw` method
     * This method is provided to allow users to completely withdraw from the vault
     *
     * Emits a {Withdraw} event.
     */

    function withdrawAll() external {
        uint256 amount = balanceOf(msg.sender);
        require(amount > 0, "Amount must be greater than 0");

        _ensureLinkAmount(amount);

        _burnShares(msg.sender, shares[msg.sender]);

        IERC20(LINK).transfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount);
    }

    /**
     * @notice Moves `_amount` myLINK from the caller's account to `_to`
     *
     * @param _to The account to transfer to
     * @param _amount The amount to transfer
     * @return true if the transfer succeeded
     *
     * Emits a {Transfer} event.
     */
    function transfer(address _to, uint256 _amount) public returns (bool) {
        _transfer(msg.sender, _to, _amount);
        return true;
    }

    /**
     * @notice Moves `_amount` myLINK from `_from` to `_to` using the allowance mechanism
     * @dev `_amount` is then deducted from the caller's allowance
     *
     * @param _from The account to transfer from
     * @param _to The account to transfer to
     * @param _amount The amount to transfer
     * @return true if the transfer succeeded
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public returns (bool) {
        require(_amount <= allowance[_from][msg.sender], "Amount exceeds allowance");

        _transfer(_from, _to, _amount);
        allowance[_from][msg.sender] -= _amount;

        return true;
    }

    /**
     * @notice Sets `_amount` as the allowance of `_spender` over the caller's myLINK
     *
     * @param _spender The account to be given an allowance
     * @param _amount The allowance amount
     * @return true if the approval succeeded
     *
     * Emits an {Approval} event.
     */
    function approve(address _spender, uint256 _amount) public returns (bool) {
        require(_spender != address(0), "Cannot approve zero address");
        allowance[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    /**
     * @notice Mints shares of myLINK according to the amount of LINK deposited
     * @dev ERC677 callback after LINK is transferred to the vault
     * @dev Can only be called by the LINK token contract
     *
     * @param _from The account that deposited the LINK
     * @param _amount The amount of LINK deposited
     * @param _data The data passed to the transferAndCall method, which must be "deposit"
     *
     * Emits a {Deposit} event.
     */
    function onTokenTransfer(
        address _from,
        uint256 _amount,
        bytes memory _data
    ) external override returns (bool) {
        require(msg.sender == LINK, "Must use LINK token");
        require(keccak256(_data) == keccak256(abi.encodePacked("deposit")), "Data must be 'deposit'");

        require(_amount > 0, "Amount must be greater than 0");
        require(totalSupply() <= MAX_CAPACITY, "Amount exceeds available capacity");

        // We must calculate the shares based on the supply before the transfer
        uint256 supplyBeforeTransfer = totalSupply() - _amount;
        uint256 newShares = supplyBeforeTransfer == 0
            ? _amount * STARTING_SHARES_PER_LINK
            : _amount.mulDivDown(totalShares, supplyBeforeTransfer);

        _mintShares(_from, newShares);

        _distributeToPlugins();

        emit Deposit(_from, _amount);

        return true;
    }

    /****************************************** OWNER METHODS ******************************************/

    modifier onlyOwner() {
        require(msg.sender == owner, "Only callable by owner");
        _;
    }

    /**
     * @notice Sets a new owner of the smart contract
     * @dev Only callable by the current owner
     *
     * @param _newOwner The address of the new owner
     *
     * Emits an {OwnershipTransferred} event.
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        owner = _newOwner;
        emit OwnershipTransferred(msg.sender, _newOwner);
    }

    /**
     * @dev ensures only the owner can upgrade the contract
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * @notice Adds a plugin to the vault
     * @dev Only callable by the owner
     * @dev Approves the plugin to transfer LINK from the vault
     * @dev Will shift all plugins with a greater priority index up by 1
     *
     * @param _plugin The address of the plugin contract
     * @param _index The priority index of the plugin
     *
     * Emits a {PluginAdded} event.
     */
    function addPlugin(address _plugin, uint256 _index) external onlyOwner {
        require(_plugin != address(0), "Cannot add zero address");
        require(_index <= pluginCount, "Index must be less than or equal to plugin count");

        uint256 pointer = pluginCount;
        while (pointer > _index) {
            plugins[pointer] = plugins[pointer - 1];
            pointer--;
        }
        plugins[pointer] = _plugin;
        pluginCount++;

        IERC20(LINK).approve(_plugin, type(uint256).max);

        emit PluginAdded(_plugin, _index);
    }

    /**
     * @notice Removes a plugin from the vault
     * @dev Only callable by the owner
     * @dev Removes the plugin's allowance to transfer LINK from the vault
     * @dev Will shift all plugins with a greater priority index down by 1
     *
     * @param _index The index of the plugin to remove
     *
     * Emits a {PluginRemoved} event.
     */
    function removePlugin(uint256 _index) external onlyOwner {
        require(_index < pluginCount, "Index out of bounds");
        address pluginAddr = plugins[_index];

        _withdrawFromPlugin(pluginAddr, IPlugin(pluginAddr).balance());

        uint256 pointer = _index;
        while (pointer < pluginCount - 1) {
            plugins[pointer] = plugins[pointer + 1];
            pointer++;
        }
        delete plugins[pluginCount - 1];
        pluginCount--;

        IERC20(LINK).approve(pluginAddr, 0);

        emit PluginRemoved(pluginAddr);
    }

    /**
     * @notice Withdraws LINK from plugins and redistributes it
     * @dev Only callable by the owner
     * @dev Useful for when the plugin configuration changes
     *
     * @param _withdrawalValues The amount of LINK to withdraw from each plugin
     */
    function rebalancePlugins(uint256[] memory _withdrawalValues) external onlyOwner {
        require(_withdrawalValues.length == pluginCount, "Invalid withdrawal values");
        for (uint256 i = 0; i < pluginCount; i++) {
            _withdrawFromPlugin(plugins[i], _withdrawalValues[i]);
        }
        _distributeToPlugins();
    }

    /**
     * @notice Sets the vault capacity
     * @dev Only callable by the owner
     *
     * @param _maxCapacity The new capacity
     */
    function setMaxCapacity(uint256 _maxCapacity) external onlyOwner {
        MAX_CAPACITY = _maxCapacity;
    }

    /****************************************** INTERNAL METHODS ******************************************/

    /**
     * @notice Mints shares of myLINK to `_to`
     *
     * @param _to The account to mint to
     * @param _shares The number of shares to mint
     */
    function _mintShares(address _to, uint256 _shares) internal {
        require(_to != address(0), "Cannot mint to address 0");

        totalShares += _shares;
        unchecked {
            // Overflow is impossible, because totalShares would overflow first
            shares[_to] += _shares;
        }
    }

    /**
     * @notice Burns shares of myLINK from `_from`
     *
     * @param _from The account to burn from
     * @param _shares The number of shares to burn
     */
    function _burnShares(address _from, uint256 _shares) internal {
        require(_from != address(0), "Cannot burn from address 0");

        require(shares[_from] >= _shares, "Cannot burn more shares than owned");
        unchecked {
            // Underflow is impossible, because of above require statement
            shares[_from] -= _shares;
            totalShares -= _shares;
        }
    }

    /**
     * @notice Transfers `_amount` myLINK from `_from` to `_to`
     * @dev Converts `_amount` to an equivalent number of shares, and transfers those shares
     *
     * @param _from The account to transfer from
     * @param _to The account to transfer to
     * @param _amount The amount to transfer
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        require(_from != address(0), "Cannot transfer from zero address");
        require(_to != address(0), "Cannot transfer to zero address");

        uint256 sharesToTransfer = convertToShares(_amount);
        require(sharesToTransfer <= shares[_from], "Amount exceeds balance");

        unchecked {
            // Underflow is impossible, because of above require statement
            shares[_from] -= sharesToTransfer;
            // Overflow is impossible because sharesToTransfer will always be less than totalShares
            // which is checked when new shares are minteds
            shares[_to] += sharesToTransfer;
        }

        emit Transfer(_from, _to, _amount);
    }

    /**
     * @notice Distributes all LINK in the vault to the plugins
     * @dev Distributes LINK to the plugin with the lowest priority index that still has capacity first
     */
    function _distributeToPlugins() internal {
        uint256 remaining = IERC20(LINK).balanceOf(address(this));

        // Plugins are ordered by priority. Fill the first one first, then the second, etc.
        for (uint256 i = 0; i < pluginCount; i++) {
            if (remaining == 0) {
                break;
            }

            address plugin = plugins[i];
            uint256 available = IPlugin(plugin).availableForDeposit();
            if (available > 0) {
                uint256 amount = available > remaining ? remaining : available;
                _depositToPlugin(plugin, amount);
                remaining -= amount;
            }
        }
    }

    /**
     * @notice Deposits `_amount` LINK to `_plugin`
     *
     * @param _plugin The address of the plugin contract
     * @param _amount The amount to deposit
     */
    function _depositToPlugin(address _plugin, uint256 _amount) internal {
        IPlugin(_plugin).deposit(_amount);
    }

    /**
     * @notice Ensures the vault has enough LINK to cover the withdrawal
     * @dev Withdraws from the plugin with the highest priority index first
     * @dev Reverts if it cannot withdraw enough LINK to satisfy the request
     *
     * @param _requested The amount of LINK to ensure the vault has
     */
    function _ensureLinkAmount(uint256 _requested) internal {
        require(_requested <= availableForWithdrawal(), "Amount exceeds available balance");

        uint256 currentBalance = IERC20(LINK).balanceOf(address(this));
        if (currentBalance >= _requested) {
            return;
        }

        uint256 remaining = _requested - currentBalance;
        // Withdraw in reverse order of deposit
        for (uint256 i = 0; i < pluginCount; i++) {
            if (remaining == 0) {
                break;
            }

            address plugin = plugins[pluginCount - i - 1];
            uint256 available = IPlugin(plugin).availableForWithdrawal();
            if (available > 0) {
                uint256 amount = available > remaining ? remaining : available;
                _withdrawFromPlugin(plugin, amount);
                remaining -= amount;
            }
        }

        if (remaining > 0) {
            revert("Unable to withdraw enough LINK from plugins");
        }
    }

    /**
     * @notice Withdraws `_amount` LINK from `_plugin`
     *
     * @param _plugin The address of the plugin contract
     * @param _amount The amount to withdraw
     */
    function _withdrawFromPlugin(address _plugin, uint256 _amount) internal {
        IPlugin(_plugin).withdraw(_amount);
    }

    /****************************************** VIEWS ******************************************/

    /**
     * @return The name of the token
     */
    function name() external pure returns (string memory) {
        return "Mycelium LINK";
    }

    /**
     * @return The symbol of the token
     */
    function symbol() external pure returns (string memory) {
        return "myLINK";
    }

    /**
     * @return The total amount of tokens in existence
     *
     * @dev Equal to the number of LINK in the vault and all plugins
     */
    function totalSupply() public view override returns (uint256) {
        uint256 supply = IERC20(LINK).balanceOf(address(this));
        for (uint256 i = 0; i < pluginCount; i++) {
            supply += IPlugin(plugins[i]).balance();
        }
        return supply;
    }

    /**
     * @return The amount of LINK the vault can receive
     */
    function availableForDeposit() public view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply >= MAX_CAPACITY) {
            return 0;
        }
        return MAX_CAPACITY - supply;
    }

    /**
     * @return The amount of LINK that can be withdrawn from the vault
     *
     * @dev The LINK in the vault, plus what can be withdrawn from the plugins
     */
    function availableForWithdrawal() public view returns (uint256) {
        uint256 available = IERC20(LINK).balanceOf(address(this));
        for (uint256 i = 0; i < pluginCount; i++) {
            available += IPlugin(plugins[i]).availableForWithdrawal();
        }
        return available;
    }

    /**
     * @return The number of tokens owned by `_account`
     * @param _account The account to query
     */
    function balanceOf(address _account) public view override returns (uint256) {
        return convertToTokens(shares[_account]);
    }

    /**
     * @notice Converts `_shares` to an equivalent number of tokens
     * @dev Rounds down
     *
     * @return The number of tokens equivalent to `_shares`
     * @param _shares The number of shares to convert
     */
    function convertToTokens(uint256 _shares) public view returns (uint256) {
        uint256 shareSupply = totalShares; // saves one SLOAD
        if (shareSupply == 0) {
            return _shares / STARTING_SHARES_PER_LINK;
        }
        return _shares.mulDivDown(totalSupply(), shareSupply);
    }

    /**
     * @notice Converts `_tokens` to an equivalent number of shares
     * @dev Rounds down
     *
     * @return The number of shares equivalent to `_tokens`
     * @param _tokens The number of tokens to convert
     */
    function convertToShares(uint256 _tokens) public view returns (uint256) {
        uint256 tokenSupply = totalSupply(); // saves one SLOAD
        if (tokenSupply == 0) {
            return _tokens * STARTING_SHARES_PER_LINK;
        }
        return _tokens.mulDivDown(totalShares, tokenSupply);
    }
}
