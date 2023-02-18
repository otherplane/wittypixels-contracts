const hashes = require("./hashes")
module.exports = {
    WitnetRequestTemplateImageDigest: {
        sources: [ 
            hashes.sources['wpx-image-digest'], 
        ],
        aggregator: hashes.reducers['mode-no-filters'],
        tally: hashes.reducers['mode-no-filters'],
    },
    WitnetRequestTemplateTokenStats: {
        sources: [
            hashes.sources['wpx-token-stats'], 
        ],
        aggregator: hashes.reducers['mode-no-filters'],
        tally: hashes.reducers['mode-no-filters'],
    }
}