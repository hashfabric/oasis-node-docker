# Oasis Protocol node

## Initial setup

```
sudo mkdir -p /data/oasis/mainnet
sudo wget https://github.com/oasisprotocol/mainnet-artifacts/releases/download/2021-04-28/genesis.json -O /data/oasis/mainnet/genesis.json
docker run -it hashfabric/oasis-core-ssvm-evmc:v21.2.8 bash
```

Follow the steps creating entity, signing transactions, etc

[Run Validator Docs](https://docs.oasis.dev/general/run-a-node/set-up-your-node/run-validator)

[Deploy OasisEth Docs](https://github.com/second-state/oasis-ssvm-runtime/wiki/Deploy-OasisEth-Paratime-on-Oasis-Mainnet)

Docker image has `oasis-registry` tool if you need it.

When done start validator/runtime node, check `docker-compose.yml` for `oasis-node` args
```
docker-compose pull
export EXTIP=<your external IP here>
docker-compose up -d
```

EXTIP can be set in `.env` file, check `.env.example`

## CheatSheet

Create entity:
```
cd /node/entity
oasis-node registry entity init
```

Initialize validator:
```
cd /node/data
ENTITY_ID=<YOUR-ENTITY-ID>
oasis-node registry node init \
  --node.entity_id $ENTITY_ID \
  --node.role validator
```

Adding the Node to the Entity Descriptor
```
cd /node/entity
oasis-node registry entity update \
  --entity.node.descriptor /node/data/node_genesis.json
```

Check that your node is synced
```
oasis-node control is-synced -a unix:/node/data/internal.sock
```

Obtain Account Address From Entity's ID
Public Key available in `/node/entity/entity.json`
```
oasis-node stake pubkey2address \
  --public_key nyjbDRKAXgUkL6CYfJP0WVA0XbF0pAGuvObZNMufgfY=
```
