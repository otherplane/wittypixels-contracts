const Witnet = require("witnet-requests")
module.exports = {
    "image-digest": {
        requestMethod: Witnet.Types.RETRIEVAL_METHODS.HttpGet,
        requestSchema: "https://",        
        requestAuthority: "\\0\\",
        requestScript: 
            "0x8218778218676445746167", 
            // new Witnet.Script([ Witnet.TYPES.STRING ])
            //     .parseJSONMap()
            //     .getString("Etag")
    },
}