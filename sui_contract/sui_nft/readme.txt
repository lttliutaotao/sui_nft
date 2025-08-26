Sui NFT项目
1、新建NFT容器
sources/collection.move：只管合集（Collection）与权限（AdminCap、MintMode、白名单、管理函数）
2、通过集合铸造NFT





sui_nft/
 ├── Move.toml
 └── sources/
      ├── collection.move   # Collection & AdminCap & 权限控制
      └── nft.move          # Token & mint 逻辑
