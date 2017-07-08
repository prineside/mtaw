var CleanCSS = require('clean-css');

var fs = require('fs');

fs.readFile('client/data/gui/css/style.min.css', 'utf8', function (err,data) {
	if ( err ) {
		return console.log( err );
	}

	var minified = new CleanCSS().minify(data).styles;

	fs.writeFile( 'client/data/gui/css/style.min.css', minified, function( err ) {
		if( err ) {
			return console.log( err );
		}

		console.log( "CSS file was minified" );
	}); 
});
