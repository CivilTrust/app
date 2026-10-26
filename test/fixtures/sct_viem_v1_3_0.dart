const sctViemFixture = <String, Object>{
  'generator': 'viem@2.56.5 account.signTypedData',
  'schema': 'Receipt(bytes32 agreementHash,uint256 dateKey,uint64 timestamp,bytes32 nonce)',
  'sct': <String, Object>{
    'version': '1.3.0',
    'domain': <String, Object>{
      'name': 'CivilTrustRegistry',
      'version': '1',
      'chainId': 421614,
      'verifyingContract': '0x1234567890123456789012345678901234567890',
    },
    'message': <String, Object>{
      'agreementHash':
          '0xc5795fee2ebbc8425ca42f8e628a7df16a78c3b926d6fbf0f91bf1300bd67ba9',
      'dateKey': 20261028,
      'timestamp': 1793145600,
      'nonce':
          '0x2b9bb631db214d595a9b3fae5726a095e01d0199a845a5de437878688db4f46e',
    },
    'signer': '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
    'signature': '0xb040c26c310ef256b0df343f47c86c087482e4ac2010eee47152369343a5df0274b0886a3d39ed3afa0c6531f85006512f7398afd329d17ff095ca01433a32701c',
  },
  'digest':
      '0x228d10e9c9647c6930bcd8af0b8bd8f769d8def0a11cf3341414ec1bde173257',
};
