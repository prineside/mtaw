Voice = {
	init = function()
		addEventHandler( "Main.onClientLoad", resourceRoot, Voice.onClientLoad )
	end;
	
	onClientLoad = function()
		addEventHandler( "onClientPlayerVoiceStart", root, Voice.onClientPlayerVoiceStart )
		addEventHandler( "onClientPlayerVoiceStop", root, Voice.onClientPlayerVoiceStop )
		addEventHandler( "onClientPlayerVoicePause", root, Voice.onClientPlayerVoicePause )
		addEventHandler( "onClientPlayerVoiceResumed", root, Voice.onClientPlayerVoiceResumed )
	end;
	
	onClientPlayerVoiceStart = function()
		Debug.info( "onClientPlayerVoiceStart" )
	end;
	
	onClientPlayerVoiceStop = function()
		Debug.info( "onClientPlayerVoiceStop" )
	end;
	
	onClientPlayerVoicePause = function()
		Debug.info( "onClientPlayerVoicePause" )
	end;
	
	onClientPlayerVoiceResumed = function()
		Debug.info( "onClientPlayerVoiceResumed" )
	end;
}

addEventHandler( "onClientResourceStart", resourceRoot, Voice.init )