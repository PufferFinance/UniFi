1. yarn install

2. start the container
`docker-compose up`

3. Create subgraph on local node `graph create --node http://localhost:8020 unifi-avs`

4. Deploy subraph to local node

```
graph codegen && graph build && graph deploy --node http://localhost:8020 --ipfs http://localhost:5001 unifi-avs
```

Use any subgraph version `1` or whatever, when prompted.

Give it some time to index everything (a few minutes)
