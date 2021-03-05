const fs = require('fs');
const path = require('path');
const Caver = require('caver-js');
const caver = new Caver('https://api.baobab.klaytn.net:8651/');

const TYPE_MINTER = '0xa8791d3acb7f4f152c41f3308e90b16e68a23666347d9c4c5ce8535dffead10d';
const TYPE_BURNER = '0x9a433df5d818859975655002918d19fe2ba4567432e52f0cec8426ddf4dc2ada';
const VERSION = '1';

async function deploy(contractName, input, address) {
    try {
        const source = fs.readFileSync(path.join(__dirname, './build/contracts/'+contractName+'.json'));
        const contract = JSON.parse(source);
        const contractToDeploy = new caver.contract(contract.abi);
        const nonce = await caver.rpc.klay.getTransactionCount(address);
        let gas;
        let result;
        if(input !== null) {
            gas = await contractToDeploy.deploy({data: contract.bytecode, arguments: input}).estimateGas({from: address});
            result = await contractToDeploy.deploy({data: contract.bytecode, arguments: input}).send({from: address, gas: gas * 10, value: 0, nonce: nonce});
        } else {
            gas = await contractToDeploy.deploy({data: contract.bytecode}).estimateGas({from: address});
            result = await contractToDeploy.deploy({data: contract.bytecode}).send({from: address, gas: gas * 10, value: 0, nonce: nonce});
        }
        return new caver.contract(contract.abi, result.options.address);
    } catch (err) {
        console.log(err);
    }
}

function argvParser(processArgv){
    let obj = {};
    if(processArgv.length !== 3){
        throw new Error('Number of parameters should be 1 - privateKey(Hex)');
    }
    obj.privateKey = processArgv[2];
    return obj;
}

async function main() {
    try {
        const input = argvParser(process.argv);
        const keyringFromPrivateKey = caver.wallet.keyring.createFromPrivateKey(input.privateKey);
        caver.wallet.add(keyringFromPrivateKey);
        const account = keyringFromPrivateKey._address;
        const source = fs.readFileSync(path.join(__dirname, './accountInfo.json'));
        const accountInfo = JSON.parse(source);
        const kip7Logic = await deploy('KIP7Logic', null, account);
        const primaryStorage = await deploy('PrimaryStorage', null, account);
        const kip7Storage = await deploy('KIP7Storage', null, account);
        const proxy = await deploy('Proxy', [primaryStorage._address], account);

        const gas = 100000000;
        const nonce = await caver.rpc.klay.getTransactionCount(account);

        await primaryStorage.methods.transferOwnership(proxy._address).send({from: account, gas: gas, nonce: nonce});
        await kip7Storage.methods.updateTokenDetails('POINT', 'HLP', '0').send({from: account, gas: gas});
        await kip7Storage.methods.transferOwnership(proxy._address).send({from: account, gas: gas});
        await proxy.methods.addAdditionalStorage(kip7Storage._address).send({from: account, gas: gas});
        await proxy.methods.updateLogicContract(kip7Logic._address, VERSION).send({from: account, gas: gas});
        await proxy.methods.addRoleType(TYPE_MINTER).send({from: account, gas: gas});
        await proxy.methods.addRoleType(TYPE_BURNER).send({from: account, gas: gas});
        await proxy.methods.grantRole(TYPE_MINTER, accountInfo.Minter).send({from: account, gas: gas});
        await proxy.methods.grantRole(TYPE_BURNER, accountInfo.Burner).send({from: account, gas: gas});

        const deployResult = {
            Proxy: proxy._address,
            PrimaryStorage: primaryStorage._address,
            KIP7Logic: kip7Logic._address,
            KIP7Storage: kip7Storage._address
        }

        const json = JSON.stringify(deployResult, null, 4);
        if(fs.existsSync(path.join(__dirname, './contract_list.json'))){
            fs.unlinkSync(path.join(__dirname, './contract_list.json'));
        }
        fs.writeFileSync(path.join(__dirname, './contract_list.json'), json);
        process.exit();
    } catch (err) {
        console.log(err);
    }
}

main();
