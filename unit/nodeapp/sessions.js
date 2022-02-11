const redis = require("redis");
const uuid = require("uuid");
const util = require("util");
const process = require("process")

let redisHost = process.env.REDIS_HOST || "127.0.0.1";
let redisUrl = "redis://" + redisHost
const client = redis.createClient(redisUrl);
const getAsync = util.promisify(client.get).bind(client);


client.on("error", function(error) {
  console.error(error);
});


function createNew(res, value) {
	let sessionId = uuid.v4();
	client.set(sessionId, JSON.stringify(value));
	client.expire(sessionId, 180);
	res.cookie("session_id", sessionId);
}

async function retrieve(req) {
	let sessionId = req.cookies["session_id"];
	if (!sessionId) 
		return null; 
	let value = await getAsync(sessionId);
	if (value == null) {
		return null;
	}
	let obj = JSON.parse(value);
	return obj;
}

module.exports = { createNew, retrieve }
