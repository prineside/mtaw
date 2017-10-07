function onNavigate() {
	var hash = window.location.hash;
	
	hideScriptSource();
	hideScriptReport();
	hideScriptTODO();
	hideScriptInfo();
	
	if ( hash != "" ) {
		// Что-то показано
		var ha = hash.split( ":" );
		if ( ha[ 0 ] == "#source" ) {
			// Исходный код скрипта
			showScriptSource( ha[ 1 ], ha[ 2 ] );
		} else if ( ha[ 0 ] == "#report" ) {
			// Отчет об ошибках
			showScriptReport( ha[ 1 ] );
		} else if ( ha[ 0 ] == "#todo" ) {
			// Список TODO
			showScriptTODO( ha[ 1 ] );
		} else if ( ha[ 0 ] == "#info" ) {
			// Информация о модуле
			showScriptInfo( ha[ 1 ] );
		}
	}
}

function executeCMD( command ) {
	var frame = $( '#execute-cmd-iframe' );
	if ( frame.length == 0 ) {
		frame = $( '<iframe id="execute-cmd-iframe" src="" style="position:fixed; top:0; left:-9999px;" width="1" height="1" />' ).appendTo( 'body' );
	}
	$( frame ).attr( "src", EXECUTE_CMD_URL + '?c=' + encodeURIComponent( command ) );
}

$( window ).bind( 'hashchange', onNavigate );
$( document ).ready( function() {
	// Если в адресной строке (хэше) есть что-то, вызываем hashchange
	if ( window.location.hash != "" ) {
		onNavigate();
	}
} );

function setActiveMenuItem( module, itemType ) {
	$( '.script' ).removeClass( 'active' );
	$( '.script' ).removeClass( 'active-type-source' );
	$( '.script' ).removeClass( 'active-type-report' );
	$( '.script' ).removeClass( 'active-type-todo' );
	$( '.script' ).removeClass( 'active-type-info' );
	
	if ( module != undefined ) {
		$( '#script-' + module ).addClass( 'active active-type-' + itemType );
	}
}

// script-source
function showScriptSource( module, lineIndex ) {
	hideScriptSource();
	
	$( '#script-source-' + module ).show();
	if ( lineIndex != undefined ) {
		$( '#sl-' + module + '-' + lineIndex ).addClass( 'highlighted' );
		
		var windowContent = $( '#script-source-' + module ).children( '.window-content' )[0];
		var scrollTop = $( '#sl-' + module + '-' + lineIndex ).position().top + 7 - $( windowContent ).height() / 2;
		
		windowContent.scrollTop = scrollTop;
		console.log( windowContent.scrollTop, scrollTop );
	}
	
	setActiveMenuItem( module, "source" );
	
	$( 'body' ).addClass( 'window-visible script-source-visible' );
}

function hideScriptSource() {
	$( '.script-source' ).hide();
	$( '.script-line-numbers span' ).removeClass( 'highlighted' );
	
	setActiveMenuItem();
	
	$( 'body' ).removeClass( 'script-source-visible' );
}

// script-report
function showScriptReport( module ) {
	hideScriptReport();
	
	$( '#script-report-' + module ).show();
	
	setActiveMenuItem( module, "report" );
	
	$( 'body' ).addClass( 'window-visible script-report-visible' );
}

function hideScriptReport() {
	$( '.script-report' ).hide();
	
	setActiveMenuItem();
	
	$( 'body' ).removeClass( 'script-report-visible' );
}

// script-todo
function showScriptTODO( module ) {
	hideScriptTODO();
	
	$( '#script-todo-' + module ).show();
	
	setActiveMenuItem( module, "todo" );
	
	$( 'body' ).addClass( 'window-visible script-todo-visible' );
}

function hideScriptTODO() {
	$( '.script-todo' ).hide();
	
	setActiveMenuItem();
	
	$( 'body' ).removeClass( 'window-visible script-todo-visible' );
}

// script-info
function showScriptInfo( module ) {
	hideScriptInfo();
	
	$( '#script-info-' + module ).show();
	
	setActiveMenuItem( module, "info" );
	
	$( 'body' ).addClass( 'window-visible script-info-visible' );
}

function hideDetailedScriptItemInfo() {
	$( '.script-info-item-details' ).stop().fadeOut( 'fast' );
	$( '#script-info-item-details-underlay' ).stop().fadeOut( 'fast' );
}

function showDetailedScriptItemInfo( detailsID ) {
	hideDetailedScriptItemInfo();
	
	var element = $( '#' + detailsID );
	
	element.appendTo( 'body' ).stop().fadeIn(150);
	$( '#script-info-item-details-underlay' ).stop().fadeIn(150);

	var width = $( window ).width() - 60;
	if ( width > 800 ) width = 800;
	
	element.css( {
		width : width,
		marginLeft : -width / 2
	} );
}

function hideScriptInfo() {
	$( '.script-info' ).hide();
	
	setActiveMenuItem();
	
	$( 'body' ).removeClass( 'window-visible script-info-visible' );
}