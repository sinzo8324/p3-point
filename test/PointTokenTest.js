const {
    time,
    constants,
    expectEvent,
    expectRevert
} = require('@openzeppelin/test-helpers');
require('chai').should();

const Proxy = artifacts.require('Proxy');
const PrimaryStorage = artifacts.require('PrimaryStorage');
const KIP7Storage = artifacts.require('KIP7Storage');
const KIP7Logic = artifacts.require('KIP7Logic');

const version = '1';
const TYPE_MINTER = '0xa8791d3acb7f4f152c41f3308e90b16e68a23666347d9c4c5ce8535dffead10d';
const TYPE_BURNER = '0x9a433df5d818859975655002918d19fe2ba4567432e52f0cec8426ddf4dc2ada';

contract('Point Token', async ([operator, minter, burner, ...accounts]) => {
    before(async () => {
        this.kip7Logic = await KIP7Logic.new({ from: operator });
        this.primaryStorage = await PrimaryStorage.new({ from: operator });
        this.kip7Storage = await KIP7Storage.new();
        this.kip7Proxy = await Proxy.new(this.primaryStorage.address, { from: operator });

        await this.primaryStorage.transferOwnership(this.kip7Proxy.address);
        await this.kip7Storage.updateTokenDetails('POINT', 'HLP', '0', { from: operator });
        await this.kip7Storage.transferOwnership(this.kip7Proxy.address, { from: operator });
        await this.kip7Proxy.addAdditionalStorage(this.kip7Storage.address, { from: operator });
        await this.kip7Proxy.updateLogicContract(this.kip7Logic.address, version, { from: operator });
        await this.kip7Proxy.addRoleType(TYPE_MINTER, { from: operator });
        await this.kip7Proxy.addRoleType(TYPE_BURNER, { from: operator });
        await this.kip7Proxy.grantRole(TYPE_MINTER, minter, { from: operator });
        await this.kip7Proxy.grantRole(TYPE_BURNER, burner, { from: operator });

        this.kip7Token = await KIP7Logic.at(this.kip7Proxy.address);
        await this.kip7Token.initialize({ from: operator });
    });

    describe('Check token details', async () => {
        it('Check Token name', async () => {
            const result = await this.kip7Token.name();
            assert.equal(result, 'POINT');
        });
        it('Check Token Symbol', async () => {
            const result = await this.kip7Token.symbol();
            assert.equal(result, 'HLP');
        });
        it('Check Token Decimals', async () => {
            const result = await this.kip7Token.decimals();
            assert.equal(result.toString(), '0');
        });
    });

    describe('mint function', async () => {
        it('only minter can use the function', async () => {
            await expectRevert(
                this.kip7Token.mint(accounts[0], 1000000, { from: accounts[0] }),
                'Caller is not the Minter'
            );
        });
        it('can not issue zero amount of token', async () => {
            await expectRevert(
                this.kip7Token.mint(accounts[0], 0, { from: minter }),
                'Can not mint zero amount'
            );
        });
        it('Transfer event should be emit after issuance has been finished successfully', async () => {
            const receipt = await this.kip7Token.mint(accounts[0], 1000000, { from: minter });
            expectEvent(receipt, 'Transfer', {
                from: constants.ZERO_ADDRESS,
                to: accounts[0],
                value: '1000000',
            });
        });
    });

    describe('burn function', async () => {
        it('only burner can use the function', async () => {
            await expectRevert(
                this.kip7Token.burn(accounts[0], 100, { from: accounts[0] }),
                'Caller is not the Burner'
            );
        });
        it('can not burn zero amount of token', async () => {
            await expectRevert(
                this.kip7Token.burn(accounts[0], 0, { from: burner }),
                'Can not burn zero amount'
            );
        });
        it('Transfer event should be emit after burning tokens has been finished successfully', async () => {
            const receipt = await this.kip7Token.burn(accounts[0], 100, { from: burner });
            expectEvent(receipt, 'Transfer', {
                from: accounts[0],
                to: constants.ZERO_ADDRESS,
                value: '100',
            });
        });
    });

    describe('transfer function', async () => {
        it('Token owner can transmit its owned tokens to the other accounts', async () => {
            const receipt = await this.kip7Token.transfer(accounts[1], '1000', { from: accounts[0] });
            expectEvent(receipt, 'Transfer', {
                from: accounts[0],
                to: accounts[1],
                value: '1000',
            });
        });
        it('reverts when transferring tokens to the zero address', async () => {
            // Conditions that trigger a require statement can be precisely tested
            await expectRevert(
                this.kip7Token.transfer(constants.ZERO_ADDRESS, '100', { from: accounts[0] }),
                'KIP7: transfer to the zero address',
            );
        });
    });

    describe('pause function', async () => {
        it('only Operator can pause the contract', async () => {
            await expectRevert(
                this.kip7Proxy.pause({ from: accounts[0] }),
                'Caller is not the Operator'
            );
        });
        it('Paused event should be emit if the contract is paused', async () => {
            const receipt = await this.kip7Proxy.pause({ from: operator });
            expectEvent(receipt, 'Paused', {
                account: operator,
            });
        });
        it('can not pause if the state of the contract paused', async () => {
            await expectRevert(
                this.kip7Proxy.pause({ from: operator }),
                'Pausable: paused'
            );
        });
        it('can not transfer tokens if the state of contract has been paused', async () => {
            await expectRevert(
                this.kip7Token.transfer(accounts[1], '100', { from: accounts[0] }),
                'Pausable: paused'
            )
        })
    });

    describe('unpause function', async () => {
        it('only Operator can unpause the contract', async () => {
            await expectRevert(
                this.kip7Proxy.unpause({ from: accounts[0] }),
                'Caller is not the Operator'
            );
        });
        it('Unpaused event should be emit if the contract is unpaused', async () => {
            const receipt = await this.kip7Proxy.unpause({ from: operator });
            expectEvent(receipt, 'Unpaused', {
                account: operator,
            });
        });
        it('can not unpause if the state of the contract unpaused', async () => {
            await expectRevert(
                this.kip7Proxy.unpause({ from: operator }),
                'Pausable: not paused'
            );
        });
    });
});
