"use strict";
var Main = {
	tooltipElement : null,
	pressedKeys : {},			// keyCode = true или undefined
	
	init : function() {
		Main.tooltipElement = $( '#tooltip' );
		
		// Прослушиваем нажатия на клавиши
		$( window ).on( 'keydown keyup', function( e ) {
			if ( e.type == "keydown" ) {
				// Нажата кнопка
				Main.pressedKeys[ e.which ] = true;
			} else {
				// Отпущена кнопка
				Main.pressedKeys[ e.which ] = undefined;
			}
		} );
	},
	
	// requestObject sendEvent( eventName, [arg1, arg2...] ).done( function( response ) {} );
	sendEvent : function( eventName ) {
		var postData = Object.create( null );
		postData.event = arguments[0];
		delete arguments[0];
		
		$.each( arguments, function( k, v ) {
			postData[ k ] = v;
		} );
		
		var returnedObject = Object.create( null );
		returnedObject.done = function( cb ) { 
			this.cb = cb
		};
		
		$.ajax({
			method: "POST",
			url: "api.html",
			data : { data: Main.toJSON( postData ) },
			async : true
		}).done(function( msg ) {
			//console.log( msg );
			if ( typeof( returnedObject.cb ) == 'function' ) {
				returnedObject.cb( msg );
			}
		});
	
		return returnedObject;
	},
	
	// Запустить Lua-скрипт на клиенте МТА (синхронно)
	// ВНИМАНИЕ! Один вызов длится примерно 16мс., все это время браузер висит
	runLua : function( code ) {
		var postData = Object.create( null );

		postData.event = "GUI.RunLua";
		postData[ 0 ] = code;
		
		var response = $.ajax({
			method: "POST",
			url: "api.html",
			data : { data: Main.toJSON( postData ) },
			async : false
		});
		
		var respText = response.responseText;
		
		if ( respText.charCodeAt( respText.length - 1 ) == 0 ) {
			// \0, сносим
			respText = respText.substring( 0, respText.length - 1 )
		}
		
		try {
			var respObj = JSON.parse( respText );
		} catch ( e ) {
			console.error( "Run Lua:", code, e, respText );
			return false;
		}
		
		var respArr = [];
		
		if ( respObj.n != 0 ) {
			for ( var i=1; i<respObj.n; i++ ) {
				respArr.push( respObj[ i ] );
			}
		}
		
		return respArr;
	},
	
	testRunLua : function() {
		var startTime = new Date().getTime();
		for ( var i=0; i<1000; i++ ) {
			Main.runLua( "return 10, 20, 30" );
		}
		var currentTime = new Date().getTime();
		
		console.log( currentTime - startTime );
	},
	
	// Debug version
	fromJSON : function( str ) {
		console.log( "Length: ", str.length );
		
		var chars = str.split( '' );
		$( chars ).each( function( k, v ) {
			console.log( v.charCodeAt( 0 ) );
		} );
		
		return JSON.parse( str );
	},
	
	toJSON : function( mixed ) {
		var cache = [];
		var jsoned = JSON.stringify(mixed, function(key, value) {
			if (typeof value === 'object' && value !== null) {
				if (cache.indexOf(value) !== -1) {
					return;
				}
				cache.push(value);
			}
			return value;
		});
		cache = null;
		
		return jsoned;
	}
};
$( document ).ready( Main.init );