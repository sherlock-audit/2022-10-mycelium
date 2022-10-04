pragma solidity ^0.8.9;

import "forge-std/Script.sol";
import "../src/Vault.sol";
import "../src/plugins/AaveV2Plugin.sol";

contract DeployScript is Script {
    function run() external {
        address link = 0x7337e7FF9abc45c0e43f130C136a072F4794d40b;
        address owner = 0x3d38f21012052C201bb94EB97eEd6F774EeC4b69;
        address lendingPool = 0x4bd5643ac6f66a5237E18bfA7d47cF22f1c9F210;
        uint256 vaultCapacity = 10e34;
        uint256 initialSharesPerToken = 1000;

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Vault vault = new Vault();
        vault.initialize(link, owner, vaultCapacity, initialSharesPerToken);
        AaveV2Plugin aavePlugin = new AaveV2Plugin(address(vault), link, lendingPool);
        vault.addPlugin(address(aavePlugin), 0);

        vm.stopBroadcast();
    }
}
