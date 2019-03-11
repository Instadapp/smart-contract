# InstaDApp V2 Contracts 

Smart contracts comprising the business logic of the InstaDApp.

## This project uses:
- [Truffle v5](https://truffleframework.com/)
- [Ganache](https://truffleframework.com/ganache)
- [Solium](https://github.com/duaraghav8/Solium)
- [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-solidity)
- [Travis CI](https://travis-ci.org/InstaDApp/InstaContract-v2) and [Circle CI](https://circleci.com/gh/InstaDApp/InstaContract-v2)
- [Coveralls](https://coveralls.io/github/InstaDApp/InstaContract-v2?branch=master)

## Installation

1. Install Truffle and Ganache CLI globally.

```javascript
npm install -g truffle@beta
npm install -g ganache-cli
```

2. Create a `.env` file in the root directory and add your private key.

## Commands:

```
Compile contracts:                  truffle compile
Migrate contracts:                  truffle migrate
Test contracts:                     truffle test
Run eslint:                         npm run lint
Run solium:                         npm run solium
Run solidity-coverage:              npm run coverage
Run lint, solium, and truffle test: npm run test
```

## License
```
MIT License

Copyright (c) 2019 InstaDApp

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
