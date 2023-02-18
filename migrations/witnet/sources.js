const Witnet = require("witnet-requests")
module.exports = {
    "wpx-image-digest": {
        requestMethod: Witnet.Types.RETRIEVAL_METHODS.HttpGet,
        requestAuthority: "\\0\\",
        requestQuery: "digest=sha-256",
        requestScript: 
            "0x811874",
            // new Witnet.Script([ Witnet.TYPES.STRING ])
            //      .length()
    },
    "wpx-token-stats": {
        requestMethod: Witnet.Types.RETRIEVAL_METHODS.HttpGet,
        requestAuthority: "\\0\\",
        requestScript:
            "0x8218771869", 
            //"0x821877811869",
            // new WitnetScript([ Witnet.TYPES.STRING ])
            //      .parseJSONMap()
            //      .valuesAsArray()
    }
}