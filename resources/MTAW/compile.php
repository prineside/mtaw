<?php
	define( 'RELEASE',	 		1 );											// Отключает DEBUG_MODE, записывает чейнджлог, компилирует файлы... Подготавливает все к релизу
	define( 'TEST_COMPILE', 	0 );											// Тестовая компиляция, имеет смысл только при $release == 1 (не обновляет чейнджлог, не трогает версию)
	define( 'USE_WEB_API', 		0 );											// Если установлено, используется веб-версия Lua-компилятора на сайте mtasa.com, в противном случае используется локальный исполняемый файл компилятора
	define( 'SKIP_COMPILE', 	0 );											// Пропустить компиляцию файлов
	
	define( 'SKIP_GIT', 		0 );											// Если установлено, будет создан коммит в локальном Git-репозитории (некое подобие автоматических резервных копий). Если репозиторий не создан, он будет инициализирован
	define( 'GIT_EXE_PATH', 'C:\\Program Files\\Git\\bin\\git.exe' );			// https://git-scm.com/download/win
	
	/*
		Требования:
		- PHP 5.3+
		- Node.js 4.0+
			set NODE_PATH=%USERPROFILE%\node_modules
			npm install clean-css (пербывая в папке compiler, если Node.js не может найти модуль clean-css)
			npm install uglify-js (пребывая в папке compiler, если Node.js не может найти модуль uglify-js)
		- compiler/luac.exe (https://luac.mtasa.com/)
	*/
	// --------------------------------
	
	set_time_limit(0);
	
	$changesDescription = null;
	$imageListString = null;
	
	if ( RELEASE && !TEST_COMPILE ) {
		// Проверяем, есть ли что-то в чейнджлоге и есть ли описание обновление
		$changes = file( "changelog" );
		$noChanges = true;
		$haveThingsToBeDone = 0;
		
		foreach ( $changes as $changeLine ) {
			if ( trim( $changeLine ) != "" && $changeLine{0} != '#' ) {
				if ( $changeLine{0} == '?' ) {
					// Описание обновлений
					$changesDescription = trim( substr( $changeLine, 1 ) );
				} else if ( $changeLine{0} == '@' ) {
					// Список изображений через запятую
					$imageListString = trim( substr( $changeLine, 1 ) );
				} else if ( $changeLine{0} == '-' ) {
					// Незаконченное дело
					$haveThingsToBeDone++;
				} else {
					$noChanges = false;
				}
			}
		}
		if ( $haveThingsToBeDone != 0 ) {
			echo 'Error: ' . $haveThingsToBeDone . " things in TODO, do it first you lazy ass!\r\n";
			die();
		}
		if ( $imageListString === null ) {
			echo "Error: there's no image list defined for update (@ 1, 2, 3 or simply @ for no img)\r\n";
			die();
		}
		if ( $noChanges ) {
			echo 'Error: no changes in changelog file' . "\r\n";
			die();
		}
		if ( $changesDescription == null || strlen( $changesDescription ) < 10 ) {
			echo 'Error: no changes description, add them to changelog with starting "?"' . "\r\n";
			die();
		}
		
		// Увеличиваем версию [major.minor.build]
		if ( !is_file( 'compiler/version' ) ) {
			file_put_contents( 'compiler/version', '0.0.0' );
		}
		$version = file_get_contents( 'compiler/version' );
		$versionArr = explode( '.', $version );
		$versionArr[2]++;
		$version = implode( '.', $versionArr );
		file_put_contents( 'compiler/version', $version );
	} else {
		$version = file_get_contents( 'compiler/version' ) . '+ Dev';
	}
	
	// Повышаем номер билда
	if ( !is_file( 'compiler/build' ) ) {
		file_put_contents( 'compiler/build', '0' );
	}
	$buildNumber = (int)file_get_contents( 'compiler/build' ) + 1;
	file_put_contents( 'compiler/build', $buildNumber );
	
	echo 'MTA:World ' . $version . " build " . $buildNumber . "\r\n";
	echo "--------------------------\r\n";
	
	// Обновляем версию
	$versionLua = '__MTAW_Version = "' . $version . '"' . "\n";
	$versionLua .= '__MTAW_Build = ' . $buildNumber . '' . "\n";
	if ( RELEASE ) {
		$versionLua .= 'DEBUG_MODE = false';
	} else {
		$versionLua .= 'DEBUG_MODE = true';
	}
	file_put_contents( "includes/version.lua", $versionLua );
	
	// Генерируем список файлов для замены моделей (так как МТА не позволяет читать папки, а использовать для этого отдельный плагин излишне)
	// Можно заменять без .col (модели транспорта)
	/*
	$modelList = array();
	//$modelList[] = "# ID, COL, DFF, TXD, COL Size, DFF Size, TXD Size,";
	$modelDirHandle = opendir( 'client/data/model' );
	$replacedModelCount = 0;
	while ( $obj = readdir( $modelDirHandle ) ) {
		if ( is_file( 'client/data/model/' . $obj ) && substr( $obj, -4 ) == '.dff' ) {
			// .dff-файл
			$modelID = substr( $obj, 0, -4 );
			if ( !is_numeric( $modelID ) ) {
				// В названии не число
				echo 'Error: model file client/data/model/' . $obj . ' has wrong name' . "\r\n";
				die();
			}
			if ( !is_file( 'client/data/model/' . $modelID . '.txd' ) ) {
				// .txd не найден
				echo 'Error: .txd file for model ' . $modelID . ' not found' . "\r\n";
				die();
			} else {
				// Все файлы на месте
				$colHash = false;
				if ( is_file( 'client/data/model/' . $modelID . '.col' ) ) {
					$colHash = strtoupper( substr( md5( file_get_contents( 'client/data/model/' . $modelID . '.col' ) ), 0, 4 ) );
				}
				$txdHash = strtoupper( substr( md5( file_get_contents( 'client/data/model/' . $modelID . '.txd' ) ), 0, 4 ) );
				$dffHash = strtoupper( substr( md5( file_get_contents( 'client/data/model/' . $modelID . '.dff' ) ), 0, 4 ) );
				if ( $colHash !== false ) {
					$colSize = sprintf( "%X", filesize( 'client/data/model/' . $modelID . '.col' ) );
				}
				$dffSize = sprintf( "%X", filesize( 'client/data/model/' . $modelID . '.dff' ) );
				$txdSize = sprintf( "%X", filesize( 'client/data/model/' . $modelID . '.txd' ) );
				
				$sep = 'O';
				if ( $colHash === false ) {
					//echo $modelID . ' has no col' . "\n";
					$modelList[] = sprintf( "%X", $modelID ) . $sep . $dffHash . $sep . $txdHash . $sep . $dffSize . $sep . $txdSize . $sep;
				} else {
					$modelList[] = sprintf( "%X", $modelID ) . $sep . $colHash . $sep . $dffHash . $sep . $txdHash . $sep . $colSize . $sep . $dffSize . $sep . $txdSize . $sep;
				}
				$replacedModelCount++;
			}
		}
	}
	file_put_contents( 'client/data/models.txt', implode( "\r\n", $modelList ) );
	echo 'Generated replaces list for ' . $replacedModelCount . ' models' . "\n";
	*/
	
	// Генерируем meta.xml
	if ( RELEASE ) {
		// Релиз - компилируем файлы, добавляем changelog
		
		// Changelog
		$changes = file( "changelog" );
		$noChanges = true;
		foreach ( $changes as $changeLine ) {
			if ( trim( $changeLine ) != "" && $changeLine{0} != '#' ) {
				$noChanges = false;
				break;
			}
		}
		if ( !$noChanges ) {
			// Есть записи в changelog
			$changesFiltered = array();
			$comments = array();
			foreach ( $changes as $changeLine ) {
				$changeLine = trim( $changeLine );
				if ( $changeLine != '' && $changeLine{0} != '#' && $changeLine{0} != '?' && $changeLine{0} != '@' ) {
					$changesFiltered[] = str_replace( '|', '/', $changeLine );
				} else if ( $changeLine != '' && $changeLine{0} == '#' ) {
					$comments[] = $changeLine;
				}
			}
			
			// Запись в changelog.lua
			if ( !TEST_COMPILE ) {
				$changelogLua = file( 'includes/changelog.lua' );
				$src = fopen( 'includes/changelog.lua', 'w' );
				foreach ( $changelogLua as $oldLineIdx => $oldLine ) {
					if ( $oldLineIdx == 1 ) {
						fwrite( $src, "\t[\"" . $version . "\"] = \"" . str_replace( "\"", "\\\"", implode( '|', $changesFiltered ) ) . "\";--" . time() . "\n" );
					}
					fwrite( $src, $oldLine );
				}
				fclose( $src );
				
				file_put_contents( 'changelog', implode( "\n", $comments ) );
			}
		}
		
		// Генерация meta
		$metaData = file( "meta.src.xml" );
	
		$destMetaFile = fopen( "meta.xml", "w" );
	
		// Генерация meta.xml и установка handles.xml
		// Также собирается список CSS-файлов и генерируется один файл
		if ( !is_dir( 'compiled' ) ) mkdir( 'compiled' );
	
		$fileList = array();
		$filesCounter = 0;
		
		$cssFileList = array();
		$jsFileList = array();
		$shaderFileList = array();
		
		$mainJsFileIncluded = false;
		
		foreach ( $metaData as $k => $v ) {
			if ( substr( trim( $v ), 0, 7 ) == "<script" ) {
				// Скрипт
				preg_match( '/src="([^\"]+)"/', trim( $v ), $matches );
				$filePath = $matches[ 1 ];
				preg_match( '/type="([^\"]+)"/', trim( $v ), $matches );
				$fileType = $matches[ 1 ];
				
				if ( $fileType == "client" || $fileType == "shared" ) {
					$filesCounter++;
					
					$filePathExpl = explode( '/', $filePath );
					$fileDirName = '';
					if ( array_key_exists( sizeof( $filePathExpl ) - 2, $filePathExpl ) ) {
						$fileDirName = $filePathExpl[ sizeof( $filePathExpl ) - 2 ] . '/';
						if ( !is_dir( 'compiled/' . $fileDirName ) ) {
							mkdir( 'compiled/' . $fileDirName );
						}
					}
					$fileName = substr( $filePathExpl[ sizeof( $filePathExpl ) - 1 ], 0, -4 );
					
					$newFilePath = 'compiled/' . $fileDirName . $fileName . ".luac";
					$fileList[] = array(
						'old' => $filePath,
						'new' => $newFilePath
					);
					
					if ( $fileType == "shared" ) {
						// На клиент и сервер
						fwrite( $destMetaFile, '	<script src="' . $filePath . '" type="server"></script>' . "\n" );
						fwrite( $destMetaFile, '	<script src="' . $newFilePath . '" type="client"></script>' . "\n" );
					} else {
						// Только клиент
						fwrite( $destMetaFile, '	<script src="' . $newFilePath . '" type="client"></script>' . "\n" );
					}
				} else {
					fwrite( $destMetaFile, $v );
				}
			} else if ( substr( trim( $v ), 0, 5 ) == "<file" ) {
				// Файл
				preg_match( '/src="([^\"]+)"/', trim( $v ), $matches );
				$filePath = $matches[ 1 ];
				
				if ( substr( $filePath, -4 ) == '.css' ) {
					// CSS-файл, добавляем в список стилей для обфускации
					if ( substr( $filePath, -9 ) == 'style.css' ) {
						// Вместо style.css вставляем style.min.css, который сгенерируем дальше
						fwrite( $destMetaFile, '			<file src="client/data/gui/css/style.min.css" />' . "\n" );
					} else {
						// Другой стиль, добавляем в список на обфускацию
						$cssFileList[] = $filePath;
					}
				} else if ( substr( $filePath, -3 ) == '.js' ) {
					// JS-файл, добавляем в список для обфускации
					if ( !$mainJsFileIncluded ) {
						fwrite( $destMetaFile, '			<file src="client/data/gui/js/script.min.js" />' . "\n" );
						$mainJsFileIncluded = true;
					}
					$jsFileList[] = $filePath;
				} else if ( substr( $filePath, -3 ) == '.fx' ) {
					// FX-файл, добавляем в список для упаковки в исходники
					if ( substr( $filePath, -13 ) == 'mta-helper.fx' ) {
						// Стандартный mta-helper пропускаем, он используется другими шейдерами
						fwrite( $destMetaFile, $v );
					} else {
						// Другой шейдер - добавляем в список
						$shaderFileList[] = $filePath;
					}
				} else {
					// Другой файл, пропускаем
					fwrite( $destMetaFile, $v );
				}
			} else {
				fwrite( $destMetaFile, $v );
			}
		}
		fclose( $destMetaFile );
		
		// Запись всех шейдеров в /includes/shaders.lua
		$shadersArrFileContents = 'ARR_Shaders = {' . "\n";
		foreach ( $shaderFileList as $shaderFilePath ) {
			$shaderContents = file_get_contents( $shaderFilePath );
			$shadersArrFileContents .= '["' . $shaderFilePath . '"] = "' . base64_encode( $shaderContents ) . '";' . "\n";
		}
		$shadersArrFileContents .= '};';
		file_put_contents( 'includes/shaders.lua', $shadersArrFileContents );
					
		// Обфускация стилей
		// -- Заменяем путь на файл стилей в index.html
		$indexHTML = file_get_contents( 'client/data/gui/index.html' );
		$indexHTML = str_replace( '<!-- <link rel="stylesheet" href="css/style.css" /> -->', '<link rel="stylesheet" href="css/style.css" />', $indexHTML );
		$indexHTML = str_replace( '<link rel="stylesheet" href="css/style.css" />', '<!-- <link rel="stylesheet" href="css/style.css" /> -->', $indexHTML );
		$indexHTML = str_replace( '<!-- <link rel="stylesheet" href="css/style.min.css" /> -->', '<link rel="stylesheet" href="css/style.min.css" />', $indexHTML );
		
		// -- Соединяем стили
		$mergedCSS = '';
		foreach ( $cssFileList as $cssFilePath ) {
			$mergedCSS .= "\n" . file_get_contents( $cssFilePath );
		}
		$mergedCSS = str_replace( array( "\t", "\r\n", "\n" ), '', $mergedCSS );
		file_put_contents( 'client/data/gui/css/style.min.css', $mergedCSS );
		
		system( 'node compiler/css-obfuscate.js' );
		
		// Обфускация скриптов JS
		// -- Заменяем путь на файл со всеми скриптами в index.html
		$indexHTML = str_replace( '<!-- <script src="js/script.min.js"></script> -->', '<script src="js/script.min.js"></script>', $indexHTML );
		$indexHTML = str_replace( '<!-- JS files -->', '<!-- JS files --/', $indexHTML );
		$indexHTML = str_replace( '<!-- /JS files -->', '/!-- /JS files -->', $indexHTML );
		
		// -- Соединяем скрипты
		$mergedJS = '';
		foreach ( $jsFileList as $jsFilePath ) {
			$mergedJS .= "\n" . file_get_contents( $jsFilePath );
		}
		file_put_contents( 'client/data/gui/js/script.min.js', $mergedJS );
		
		system( 'node compiler/js-obfuscate.js' );
		
		// Сохраняем index.html
		file_put_contents( 'client/data/gui/index.html', $indexHTML );
		
		// Компиляция
		// -- Достаем список версий скомпилированных файлов
		$alreadyCompiled = array();
		if ( is_file( 'compiler/compilation-cache.json' ) ) {
			$alreadyCompiled = json_decode( file_get_contents( 'compiler/compilation-cache.json' ), true );
		}
		$currentlyCompiled = array();
		
		// -- Компилируем
		@mkdir( 'compiled' );
		// 0 - не скомпилировано, 1 - скомпилировано, 2 - не нужно компилировать
		function doCompile( $src, $dst ) {
			global $alreadyCompiled, $currentlyCompiled;
			
			if ( !is_file( $src ) ) {
				echo 'File ' . $src . ' not found, compilation aborted' . "\n";
				die();
			}
			
			// Проверяем, не скомпилирован ли файл уже
			if ( array_key_exists( $src, $alreadyCompiled ) ) {
				// Файл уже был компилирован, проверяем хэши
				if ( md5( file_get_contents( $src ) ) == $alreadyCompiled[ $src ][ 'src-hash' ] ) {
					// Хэш исходников не поменялся, проверяем бинарник
					if ( is_file( $dst ) && md5( file_get_contents( $dst ) ) == $alreadyCompiled[ $src ][ 'dst-hash' ] ) {
						// Хэш бинарника не поменялся, это компилировать не нужно
						$currentlyCompiled[ $src ] = $alreadyCompiled[ $src ];
						return 2;
					}
				}
			}
			
			// Продолжаем компиляцию
			if ( USE_WEB_API ) {
				$ch = curl_init();
				curl_setopt_array( $ch, array(
					CURLOPT_URL => 'http://luac.mtasa.com/index.php',
					CURLOPT_RETURNTRANSFER => true,
					CURLOPT_POST => true,
					CURLOPT_POSTFIELDS => http_build_query( array(
						'luasource' => file_get_contents( $src ),
						'compile' => 1,
						'debug' => 1,
						'obfuscate' => 1
					) )
				) );
				$response = curl_exec( $ch );
				curl_close( $ch );
				
				if ( !empty( $response ) ) {
					file_put_contents( $dst, $response );
					$currentlyCompiled[ $src ] = array(
						'src-hash' => md5( file_get_contents( $src ) ),
						'dst-hash' => md5( file_get_contents( $dst ) )
					);
					
					return 1;
				} else {
					return 0;
				}
			} else {
				$last_line = false;
				if ( TEST_COMPILE ) {
					$last_line = exec( 'compiler\\luac -e -o ' . $dst . ' ' . $src, $retval );
				} else {
					$last_line = exec( 'compiler\\luac -s -e -o ' . $dst . ' ' . $src, $retval );
				}
				
				if ( !empty( $last_line ) ) {
					echo $last_line . "\n";
				}
				
				if ( stripos( $last_line, 'error' ) !== false ) {
					return 0;
				} else {
					$currentlyCompiled[ $src ] = array(
						'src-hash' => md5( file_get_contents( $src ) ),
						'dst-hash' => md5( file_get_contents( $dst ) )
					);
					
					return 1;
				}
			}
		}
		
		if ( !SKIP_COMPILE ) {
			echo 'Compiling ' . $filesCounter . ' files...' . "\n";
			foreach ( $fileList as $k => $data ) {
				$compilationResult = false;
				$faultCount = 0;
				while ( $compilationResult == false ) {
					$compilationResult = doCompile( $data['old'], $data['new'] );
					if ( $compilationResult == 0 ) {
						// Не скомпилировано
						$faultCount++;
						if ( $faultCount < 3 ) {
							echo 'Failed to compile ' . $data['old'] . ', retrying...' . "\n";
						} else {
							echo 'Aborting' . "\n";
							die();
						}
					} else if ( $compilationResult == 1 ) {
						// Скомпилировано
						echo ( $k + 1 ) . '/' . $filesCounter . ' : ' . $data['old'] . " compiled \n";
					} else if ( $compilationResult == 2 ) {
						// Компиляция не требуется
						// echo ( $k + 1 ) . '/' . $filesCounter . ' : ' . $data['old'] . " not changed\n";
					}
				}
			}
			
			// Записываем в кэш
			file_put_contents( 'compiler/compilation-cache.json', json_encode( $currentlyCompiled ) );
		} else {
			echo 'Compilation skipped' . "\n";
		}
		
		// Настройка базы данных
		if ( TEST_COMPILE ) {
			copy( "compiler/db-handles-debug.xml", "server/data/db-handles.xml" );
		} else {
			copy( "compiler/db-handles-release.xml", "server/data/db-handles.xml" );
		}
	} else {
		// Локальная версия - просто копируем
		copy( "meta.src.xml", "meta.xml" );
		
		// Изменяем путь к CSS в index.html
		$indexHTML = file_get_contents( 'client/data/gui/index.html' );
		$indexHTML = str_replace( '<!-- <link rel="stylesheet" href="css/style.min.css" /> -->', '<link rel="stylesheet" href="css/style.min.css" />', $indexHTML );
		$indexHTML = str_replace( '<link rel="stylesheet" href="css/style.min.css" />', '<!-- <link rel="stylesheet" href="css/style.min.css" /> -->', $indexHTML );
		$indexHTML = str_replace( '<!-- <link rel="stylesheet" href="css/style.css" /> -->', '<link rel="stylesheet" href="css/style.css" />', $indexHTML );
		
		// Раскоментируем пути к JS в index.html
		$indexHTML = str_replace( '<!-- <script src="js/script.min.js"></script> -->', '<script src="js/script.min.js"></script>', $indexHTML );
		$indexHTML = str_replace( '<script src="js/script.min.js"></script>', '<!-- <script src="js/script.min.js"></script> -->', $indexHTML );
		$indexHTML = str_replace( '<!-- JS files --/', '<!-- JS files -->', $indexHTML );
		$indexHTML = str_replace( '/!-- /JS files -->', '<!-- /JS files -->', $indexHTML );
		
		file_put_contents( 'client/data/gui/index.html', $indexHTML );			
		
		// Настройка базы данных
		copy( "compiler/db-handles-debug.xml", "server/data/db-handles.xml" );
	}
	// Обновляем репозиторий
	if ( !SKIP_GIT ) {
		if ( is_file( GIT_EXE_PATH ) ) {
			if ( !is_dir( '.git' ) ) {
				// Репозиторий еще не установлен, создаем
				exec( '"' . GIT_EXE_PATH . '" init' );
				exec( '"' . GIT_EXE_PATH . '" config core.autocrlf false' );
				echo 'Initialized GIT repo' . "\n";
			}
			exec( '"' . GIT_EXE_PATH . '" add .' );
			exec( '"' . GIT_EXE_PATH . '" commit -m "' . $version . ' build ' . $buildNumber . '"' );
			echo 'GIT updated' . "\n";
		} else {
			echo 'No git.exe, commit cancelled' . "\n";
		}
	} else {
		echo 'GIT skipped' . "\n";
	}
	
	echo "Done\n";