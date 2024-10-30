What is there:

- Abstracted account with the check for owner's signature
- Factory of those accounts, calling of which happens in EntryPoint
- Paymaster with the check for owner's/signer's signature
- A way to send PackedUserOperations
- ERC6900 dummy Subscription module (will redo later with subscription NFT's)


To run tests
```shell
forge test
```