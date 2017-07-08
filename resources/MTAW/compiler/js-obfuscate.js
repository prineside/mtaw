var UglifyJS = require("uglify-js");

var fs = require('fs');

fs.readFile('client/data/gui/js/script.min.js', 'utf8', function (err,data) {
	if ( err ) {
		return console.log( err );
	}
	
	var minified = UglifyJS.minify(data, {fromString: true});

	fs.writeFile( 'client/data/gui/js/script.min.js', minified.code, function( err ) {
		if( err ) {
			return console.log( err );
		}

		console.log( "JS file was minified" );
	}); 
});
