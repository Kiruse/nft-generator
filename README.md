# Kiru's HashLips Mod
Kiru's modification of [HashLips' generative-art-node](https://github.com/HashLips/generative-art-node).

I say it's a fork, but it's really a complete rewrite (in CoffeeScript!) using their code as foundation.

1. Weighted rarity in filenames by format `<filename>#<weight>.<ext>`
2. Export trait combinations to CSV
3. Forbidden traits & mutually exclusive traits - reroll when encountered

Run the NFT image & metadata generation with `yarn generate`

## Caveat
Sometimes, yarn may freak out while installing canvas and never actually complete. In that case, simply abort, delete `node_modules`, and retry. I find this usually works.
