<?php
	mb_internal_encoding( "UTF-8" );
	
	// Статистика (строк, символов, файлов)
	function gatherFilePaths( $dirPath ) {
		$dirPath = rtrim( $dirPath, '/' ) . '/';
		
		$filePaths = array();
		
		$src = opendir( $dirPath );
		while ( $obj = readdir( $src ) ) {
			if ( $obj == '.' || $obj == '..' ) continue;
			
			if ( is_file( $dirPath . $obj ) ) {
				$filePaths[] = $dirPath . $obj;
			} else {
				$filePaths = array_merge( $filePaths, gatherFilePaths( $dirPath . $obj ) );
			}
		}
		
		return $filePaths;
	}
	
	$include = array(
		"./meta.src.xml", 
		"./client/", 
		"./includes/", 
		"./server/"
	);
	$exclude = array(
		"./includes/arrays/farm_fields.lua",
		"./server/data/debug-bugreports/",
		"./client/data/gui/fonts/",
	);
	$extensions = array(
		".lua", ".js", ".css", ".html", ".fx", ".xml"
	);
	
	$files = gatherFilePaths( './' );
	
	$fileLines = 0;
	$fileCharacters = 0;
	$fileCount = 0;
	foreach ( $files as $filePath ) {
		$valid = false;
		foreach ( $include as $includedPrefix ) {
			if ( mb_substr( $filePath, 0, mb_strlen( $includedPrefix ) ) == $includedPrefix ) {
				$valid = true;
				break;
			}
		}
		if ( !$valid ) continue;
		
		foreach ( $exclude as $excludedPrefix ) {
			if ( mb_substr( $filePath, 0, mb_strlen( $excludedPrefix ) ) == $excludedPrefix ) {
				$valid = false;
				break;
			}
		}
		if ( !$valid ) continue;
		
		$valid = false;
		foreach ( $extensions as $ext ) {
			if ( mb_substr( $filePath, -mb_strlen( $ext ) ) == $ext ) {
				$valid = true;
				break;
			}
		}
		
		if ( $valid ) {
			$fileCount++;
			$fileLines += sizeof( file( $filePath ) );
			$fileCharacters += mb_strlen( file_get_contents( $filePath ) );
		}
	}
	
	echo $fileCount . ' files' . "\n";
	echo number_format( $fileLines ) . ' lines' . "\n";
	echo number_format( $fileCharacters ) . ' characters' . "\n";