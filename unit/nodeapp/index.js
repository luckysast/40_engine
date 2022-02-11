#!/usr/bin/env node

const process = require('process');
const unitHttp = require('unit-http');
const http = require('http')

http.ServerResponse = unitHttp.ServerResponse
http.IncomingMessage = unitHttp.IncomingMessage

const mongoose = require('mongoose');
const express = require('express');
const bodyParser = require('body-parser');
const cookieParser = require('cookie-parser');
const app = express()
const sessions = require("./sessions");

app.use(bodyParser.json());
app.use(cookieParser());

const Schema = mongoose.Schema;
const ObjectId = Schema.ObjectId;

const UserSchema = new Schema({
	id: ObjectId,
	username: String,
	password: String,
	description: String
});

const User = mongoose.model('User', UserSchema)

app.post('/register', async (req, res) => {
	let username = req.body["username"]
	let password = req.body["password"]
	let description = req.body["description"]

	if (username.indexOf("/") != -1) {
		res.send({"error": "Incorrect username"});
		return;
	}

	let exists = await User.exists({ username: username });
	if (exists) {
		res.send({"error": "User exists"});
		return;
	}

	const user = await User.create({
		username: username, 
		password: password,
		description: description
	});

	res.send("ok")
});

app.get('/register', (req, res) => {
	res.sendFile(__dirname + "/views/signup.html");
});

app.get('/home', async (req, res) => {
        let session = await sessions.retrieve(req);
        if (session == null) {
                res.redirect('/login')
                return;
        }
	res.sendFile(__dirname + "/views/home.html");
});

app.get('/users', (req, res) => {
	res.sendFile(__dirname + "/views/users.html");
});

app.post('/users', (req, res) => {
	User.find({}, function(err, users) {
		var userMap = {};
		
		users.forEach(function(user) {
			userMap[user._id] = {"username": user.username};
		});

		res.send(userMap);  
	});
});

app.get('/license', async (req, res) => {
        let session = await sessions.retrieve(req);
        if (session == null) {
                res.redirect('/login')
                return;
        }
	res.sendFile(__dirname + "/views/license.html");
});

app.get('/bf_engine', async (req,res) => {
        let session = await sessions.retrieve(req);
        if (session == null) {
                res.redirect('/login')
                return;
        }
	res.sendFile(__dirname + "/views/bf.html");
});

app.get('/bf_engine_load', async (req,res) => {
        let session = await sessions.retrieve(req);
        if (session == null) {
                res.redirect('/login')
                return;
        }
        res.sendFile(__dirname + "/views/bf_old.html");
});

app.post('/login', async (req, res) => {
	let { username, password } = req.body;

	const exists = await User.exists({
		username: username,
		password: password
	});

	if (exists) {
		sessions.createNew(res, { username: username })
		res.send("ok")
		return;
	}

	res.send({"exists": exists});
});

app.get('/login', (req, res) => {
	res.sendFile(__dirname + "/views/login.html");
});

app.get('/profile', async (req, res) => {
	let session = await sessions.retrieve(req);
	if (session == null) {
		res.redirect('/login')
		return;
	} 

	let username = session['username'];
	console.error(username)
	console.error(session)
	let query = { username: username };
	let user = await User.findOne(query);
	res.send(user);
});

app.get('/', (req, res) => res.redirect('/profile'))

unitHttp.createServer(app).listen()

function connectToMongo() {
        let mongoHost = process.env.MONGO_HOST || '127.0.0.1';
        var mongoUrl = 'mongodb://' + mongoHost + '/database';
        mongoose.connect(mongoUrl, function(err){
                if(err) {
                        console.log("can't connect mongodb retry...");
			setTimeout(() => {
				connectToMongo();
			}, 1000);
                } else {
                        console.log("MongoDB connection...");
                }
        });
}

setTimeout(() => {
        connectToMongo();
}, 5000);
