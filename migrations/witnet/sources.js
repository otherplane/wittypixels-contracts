const Witnet = require("witnet-requests")
module.exports = {
    "image-digest": {
        requestMethod: Witnet.Types.RETRIEVAL_METHODS.HttpGet,
        requestSchema: "https://",        
        requestAuthority: "\\0\\",
        requestQuery: "base64=true",
        requestScript: 
            "0x811874",
            // new Witnet.Script([ Witnet.TYPES.STRING ])
            //      .length()
    },
    "token-stats": {
        requestMethod: Witnet.Types.RETRIEVAL_METHODS.HttpGet,
        requestSchema: "https://",
        requestAuthority: "\\0\\",
        requestScript:
            "0x8218771869", 
            //"0x821877811869",
            // new WitnetScript([ Witnet.TYPES.STRING ])
            //      .parseJSONMap()
            //      .valuesAsArray()
    }
}