<?php
	/*
		TODO
		- парсинг синтаксиса событий
	
		Ищет ошибки стилизации кода и неправильные вызовы функций других модулей (внутреннего использования), а также обработчики внутренних
		событий других модулей. Генерирует документацию по каждому модулю, создает файл inspect.html с описанием всех общих функций и событий 
		каждого модуля, а также списки ошибок и комментариев со словом TODO.
		
		Зависимости:
			- PHP 5.4, прописанный в PATH (для запуска через inspect.bat). Можно не прописывать в PATH и указывать полный путь к php.exe
			- Чтобы открывать код в Notepad++ при клике на ссылку, нужно:
				- Скопировать inspector/privatecmdrun.exe в C:/php/
				- Запустить inspector/privatecmdrun-protocol.reg (чтобы добавить протокол privatecmdrun://)
				  Можно изменить путь к privatecmdrun.exe в privatecmdrun-protocol.reg, а также имзенить название протокола (см. исходный код .cs)
				- [Опционально] Изменить константу NPP_EXE_PATH, если путь к N++ изменен
				- [Опционально] Изменить константу PRIVATECMDRUN_PROTOCOL, если privatecmdrun.exe был скомпилирован с другим именем протокола
		
		Использование:
			1. Shift + ПКМ в каталоге с inspect.php -> "Открыть окно команд"
			2. В командной строке ввести "php inspect.php"
			3. Дождаться завершения проверки и открыть inspect.html в браузере (желательно Chrome, но работает и в Firefox. На других не тестировалось)
		
		Инструкции:
			- Секции задаются в виде:
			  ------------------------------------------------------------------
			  --<[ Общие события ]>---------------------------------------------
			  ------------------------------------------------------------------
			  Длина строки (реальная, с учетом \t == 4 пробела) должна быть ровно 80 символов, название секции должно быть окружено строками,
			  состоящими только из знака комментария (тоже 80 в длину строки)
			- Список событий модуля должен находиться внутри секций "Общие события" (доступные другим модулям) и "Внутренние события" (которые
			  можно использовать только внутри этого же модуля)
			- Таблица модуля должна находиться в секции "Модуль ModuleName" (где ModuleName - название модуля). В файле должна быть по крайней
			  мере одна секция вида "Модуль ...", это обязательное условие, так как название из секции считается именем модуля
			- Функция модуля считается общей (public) и вносится в документацию, если она находится на первом уровне таблицы модуля. Из общих 
			  функций исключаются:
			  - функция init(), так как она используется во время инициализации модуля
			  - функции, которые начинаются с символа "_" - такие функции считаются private и могут быть вызваны только внутри модуля
			  - функции, которые начинаются с on[Символ в большом регистре] - такие функции считаются private обработчиками событий модуля и также
			    не могут быть вызваны в других модулях
			- Вызов функции с именем, идентичным названию любого существующего модуля, расценивается как вызов метода create этого модулья, например
			  при вызове Container() при существовании модуля Container вызов будет считаться как Container.create()
			- Каждая общая (public) функция должна иметь общее описание, описание аргументов функции и возвращаемых значений. Описание должно
			  находиться на строке, которая предшествует строке оглашения функции, и иметь вид:
			  -- Общее описание, строка 1
			  -- Общее описание, строка ...
			  -- Общее описание, строка n
			  -- > argName1 string - описание первого аргумента
			  -- > argName2 number - описание второго аргумента ...
			  -- > argNameN table / nil - описание последнего аргумента с несколькими возможными типами данных
			  -- = table result, string / nil name - возвращаемые значения (или -- = void, если не возвращает ничего)
			  setItem = function( argName1, argName2, argNameN ) ... end
			- Первый аргумент методов объектов должен иметь имя "self". Функция считается методом объекта, если ее первый аргумент имеет имя "self".
			- Есть два типа событий - с источником в виде элементов (стандартные события, addEvent...) и с источником в виде таблиц (объектов, как 
			правило для shared классов). Инспектор вносит в документацию только стандартную систему событий.
			
		Ищет ошибки:
			- События, не начинающиеся с Module.on* ( события должны иметь названия в виде Account.onPlayerLogIn )
			- События, заданные вне секции "Общие события" или "Внутренние события"
			- События, у которых нет описания или синтаксиса ( addEvent( "Event.test", true ) -- ( resource a, boolean b ) Описание события (даже для внутреннего) )
			- Функции, у которых нет описания
			- Модули пытаются обработать внутренние события других модулей
			- Модули пытаются вызвать функцию вида on[большая буква] другого модуля, или функцию другого модуля, начинающуюся с _
			
		Структура файловой системы:
			- inspect.php находится в корне ресурса (на одном уровне с каталогами "client" и "server")
			- Каталог "inspector" находится в корне (рядом с inspect.php), содержит стили, скрипты и шрифты для отчета инспектора (inspect.html)
			  Также в этом каталоге находится кэш (.json-файлы, включающие и исходный код скриптов модулей) и файлы для создания протокола запуска N++
			- Скрипт предполагает наличие файла "meta.src.xml" в корне ресурса и соответствующую структуру файлов модулей (с одним уровнем вложения каталогов)
			
	*/
	
	/*
		Структура scriptData (self::$_scriptsParsedData):
		
		scriptData => Array ( index: scriptPath )
			[scriptID] => String
			[moduleType] => String												- client/server/shared
			[moduleNameCamel] => String
			[errors] => Array
				[lineIndex] => Number
				[message] => String
			[comments] => Array ( index: lineIndex )							- Комментарии (lineIndex => comment)
			[lines] => Array ( index: lineIndex )
				[tabSize] => Number
				[lineNumber] => Number
				[rawSource] => String
				[source] => String
				[inMultilineComment] => Bool
				[section] => String
				[sourceSemicolon] => String
            [oneline] => String
			[onelineMap] => Array ( index: lineIndex )
            [onelineNostring] => String
			[onelineNostringMap] => Array ( index: lineIndex )
			[onelineNostringWorking] => String
			[strings] => Array ( index: stringIndex )
				[string] => String
				[lineIndex] => Number
			[calledFunctions] => Array ( index: calledFunctionIndex ) 			- вызванные функции из других модулей
				[name] => String												- название функции
				[onelineOffset] => Number										- смещение с начала строки onelineNostring до начала названия функции
				[lineIndex] => Number											- строка, на которой началось объявление функции
				[args] => Array ( index: argumentIndex )						- аргументы, переданные в функцию (может быть рекурсивно)
					[type] => String											- тип аргумента (string/number/bool/nil/function/misc)
					[value] => Misc												- значение аргумента (для string - индекс строки из scriptData.strings и строка)
					[src] => String												- исходный код аргумента (не обработанный парсером)
					[offset] => Number											- смещение исходного кода аргумента относительно начала круглых скобок, в которых переданы аргументы функции
				[rootCall] => Number											- функцие вызвана не внутри вызова другой функции ( function( function() ) )
				[tableLevel] => Number											- уровень вложенности в таблицу (уровень 0 - вызвана за таблицей модуля, уровень 1 - таблица модуля)
				[blocks] => Array ( index: onelineOffset )						- блоки, в которых находится функция (do, for, function, if, от самого глобального)
			[moduleEvents] => Array ( index: eventName )	 					- заданные общедоступные события модуля
				[remoteTrigger] => Bool											- может ли событие быть вызвано извне
				[calledFunctionIndex] => Number									- индекс calledFunctionIndex из [calledFunctions] функции addEvent
				[syntax] => String
				[description] => String
			[handledEvents] => Array ( index: [] ) 								- обработанные события (из других модулей и стандартные)
				[name] => String 												- название обработанного события
				[lineIndex] => Number 											- строка, на которой добавляется обработчик
			[moduleFunctions] => Array ( index: functionName ) 					- заданные функции модуля (на первом уровне таблицы модуля)
				[description] => Array											- описание функции из комментариев перед ней
					[brief] => Array ( index: [] ) 								- массив строк с описанием функции (начинаются с комментария ---- перед функцией)
					[args] => Array ( index: argumentIndex ) 					- аргументы по порядку (начинаются с комментария -- > перед функцией)
						[dataTypes] => Array ( index: [] )						- массив строк типов данных аргументов
						[name] => String										- название аргумента
						[description] => String									- описание аргумента
					[return] => Array ( index: [] ) или null					- возвращаемые значения функции (начинаются с комментария -- = перед функцией)
						[dataTypes] => Array ( index: [] )						- тип данных возвращаемого значения
						[name] => String										- название возвращаемого значения
				[args] => Array ( index: argumentIndex ) 						- массив строк с названием переменных аргументов (действительных, не с описания)
				[lineIndex] => Number											- строка, на которой объявлена функция
	*/
	
	class Inspector {
		const ROOT = './';
		const CACHE_EXPIRATION_TIME = 60 * 60 * 24 * 7; // Не учитывается, если этот файл (inspect.php) новее кэша
		
		const NPP_EXE_PATH = 'C:/Program Files (x86)/Notepad++/notepad++.exe';
		const PRIVATECMDRUN_PROTOCOL = 'privatecmdrun://';
		const INCLUDE_SOURCE_CODE = true;				// Если false, все исходники будут заменены на крякозябры
		
		const ERR_CODE_AFTER_MULTILINE_COMMENT = 0x1;
		const ERR_MULTILINE_COMMENT_AFTER_CODE = 0x2;
		const ERR_WRONG_COMMENT_USAGE = 0x3;
		const ERR_ADD_EVENT_WRONG_SYNTAX = 0x4; 
		const ERR_WRONG_ADD_EVENT_NAME = 0x5;
		const ERR_WRONG_ADD_EVENT_DESCRIPTION = 0x6;
		const ERR_WRONG_ADD_EVENT_SECTION = 0x7;
		const ERR_WRONG_MODULE_FUNCTION_SYNTAX = 0x8;
		const ERR_WRONG_MODULE_FUNCTION_DECLARATION = 0x9;
		const ERR_NOSECTION_EVENT_HANDLER = 0xa;
		const ERR_PRIVATE_EVENT_HANDLER = 0xb;
		const ERR_EVENT_NOT_EXISTS = 0xc;
		const ERR_FUNCTION_NOT_EXISTS = 0xd;
		const ERR_PRIVATE_FUNCTION_CALL = 0xe;
		const ERR_EVENT_HANDLER_FUNCTION_CALL = 0xf;
		const ERR_MODULE_NAME_NOT_DEFINED = 0x10;
		const ERR_EVENT_MODULE_NOT_FOUND = 0x11;
		const ERR_FUNCTION_MODULE_NOT_FOUND = 0x12;
		const ERR_NO_FUNCTION_BRIEF_DESCRIPTION = 0x13;
		const ERR_NO_FUNCTION_RETURN_DESCRIPTION = 0x14;
		const ERR_NO_FUNCTION_ARGS_DESCRIPTION = 0x15;
		const ERR_EXCESSIVE_ARG_DESCRIPTION = 0x16;
		const ERR_WRONG_ARG_NAME_IN_DESCRIPTION = 0x17;
		const ERR_NO_FUNCTION_ARG_DATATYPE_DESCRIPTION = 0x18;
		const ERR_INVALID_SECTION_COMMENT_FORMAT = 0x19;
		const ERR_TOO_LONG_FUNCTION_NAME = 0x1a;
		const ERR_CYRILLIC_CHARACTER_OUTSIDE_STRING = 0x1b;
		
		const ERR_INSPECTOR_UNKNOWN_TABLE_LEVEL = 0xF001;
		
		private static $_logHandle = null;
		private static $_reportHandle = null;
		
		private static $_scripts = null;
		private static $_scriptsParsedData = array();	// scriptPath => scriptData (смотреть выше)
		public static $_scriptContents = array();
		private static $_escapedNewLines = array();	// Строки, которые начинаются внутри lua-строк (т.е. перед этим была строка с \ в конце)
		
		private static $_predefinedKeywords = array( // После которых нельзя ставить ;
			"and", "do", "else", "elseif", "for", "function", "if", "in", "local", "not", "or", "repeat", "return", "then", "until", "while"
		);
		private static $_predefinedOperators = array(
			"<", ">", "<=", ">=", "==", "~=",
			"+", "-", "*", "/", "%", "^", "..", 
			".", ":", "\\", ","
		);
		/*
		Заменено на поиск в существующих модулях
		private static $_predefinedModules = array(
			"table", "math", "exports", "debug", "string", "self"
		);
		*/
		
		private static function log( $msg, $noEcho = false ) {
			if ( self::$_logHandle == null ) {
				self::$_logHandle = fopen( 'inspector/inspector.txt', 'w' );
			}
			
			if ( gettype( $msg ) == "array" ) {
				$msg = print_r( $msg, true );
			}
			
			$datePart = date( 'd.m.Y H:i:s' ) . ' | ';
			fwrite( self::$_logHandle, $datePart . str_replace( "\n", "\n" . $datePart, $msg ) . "\n" );
			
			if ( !$noEcho ) {
				echo $msg;
				echo "\n";
			}
		}
		
		private static function reportWrite( $html ) {
			if ( self::$_reportHandle == null ) {
				self::$_reportHandle = fopen( 'inspector.html', 'w' );
			}
			
			fwrite( self::$_reportHandle, $html );
		}
		
		// Добавляет сообщение об ошибке на строке
		private static function addError( $errorCode, $scriptPath, $lineIndex, $errorMessage ) {
			self::$_scriptsParsedData[ $scriptPath ][ 'errors' ][] = array(
				'errorCode' => $errorCode,
				'lineIndex' => $lineIndex,
				'message' => $errorMessage
			);
		}
		
		// Добавляет TODO
		private static function addTODO( $scriptPath, $lineIndex, $todoMessage ) {
			self::$_scriptsParsedData[ $scriptPath ][ 'todo' ][] = array(
				'lineIndex' => $lineIndex,
				'message' => $todoMessage
			);
		}
		
		public static function start() {
			@mkdir( self::ROOT . 'inspector' );
			@mkdir( self::ROOT . 'inspector/cache' );
			
			// Очищаем устаревший кэш
			$src = opendir( self::ROOT . 'inspector/cache' );
			$cacheExpirationTime = filemtime( __FILE__ );
			if ( $cacheExpirationTime < time() - self::CACHE_EXPIRATION_TIME ) {
				$cacheExpirationTime = time() - self::CACHE_EXPIRATION_TIME;
			} 
			while ( $obj = readdir( $src ) ) {
				if ( is_file( self::ROOT . 'inspector/cache/' . $obj ) && filemtime( self::ROOT . 'inspector/cache/' . $obj ) < $cacheExpirationTime ) {
					unlink( self::ROOT . 'inspector/cache/' . $obj );
				}
			}
				
			self::log( 'Inspecting source code...' );
			
			// Собираем список исходных файлов
			$allScripts = self::getScriptList();
			
			// Берем только скрипты модулей (исключаем includes)
			$scripts = array();
			foreach ( $allScripts as $scriptMetaInfo ) {
				if ( mb_substr( $scriptMetaInfo[ 'path' ], 0, 8 ) != 'includes' ) {
					// Файл находится не в includes (модуль)
					$scripts[] = $scriptMetaInfo;
				}
			}
			
			// Парсим скрипты
			$scriptCount = sizeof( $scripts );
			$handledSciptCount = 0;
			foreach ( $scripts as $scriptMetaInfo ) {
				// Парсим файл в массив, с которым удобно работать
				$scriptData = self::parseScript( $scriptMetaInfo[ 'path' ] );
				$handledSciptCount++;
				
				$totalProgressBars = '';
				$currentProgress = $handledSciptCount / $scriptCount;
				for ( $i=0; $i<20; $i++ ) {
					$p = $i / 20;
					if ( $p < $currentProgress ) {
						$totalProgressBars .= '|';
					} else {
						$totalProgressBars .= '-';
					}
				}
				
				//*
				if ( $handledSciptCount != 1 ) {
					for ( $i=0; $i< 20 + 3 + 7; $i++ ) {
						echo chr(8);
					}
				}
				echo sprintf( "[%20s] %3d/%3d", $totalProgressBars, $handledSciptCount, $scriptCount );
				//*/
			}
			echo "\n";
			
			// Скрипты отпарсили, анализируем
			self::log( "Checking dependencies and cross-module calls..." );
			$scriptCount = sizeof( $scripts );
			$handledSciptCount = 0;
			foreach ( $scripts as $scriptMetaInfo ) {
				$scriptPath = $scriptMetaInfo[ 'path' ];
				$scriptData = self::$_scriptsParsedData[ $scriptPath ];
				
				// Обработка внутренних событий из других модулей
				foreach ( $scriptData[ 'handledEvents' ] as $handledEventIndex => $handledEvent ) {
					$eventNameExpl = explode( '.', $handledEvent[ 'name' ] );
					
					if ( sizeof( $eventNameExpl ) != 1 ) {
						// Событие модуля (в виде aaa.bbb)
						if ( $eventNameExpl[ 0 ] == $scriptData[ 'moduleNameCamel' ] ) {
							// Событие из этого же модуля
							continue; 
						}
						
						$eventCreatedBy = self::getModuleScriptPath( $scriptData[ 'moduleType' ], $eventNameExpl[ 0 ] );
						
						if ( $eventCreatedBy == false || !array_key_exists( $eventCreatedBy, self::$_scriptsParsedData ) ) {
							// Такого модуля нет
							self::addError( self::ERR_EVENT_MODULE_NOT_FOUND, $scriptPath, $handledEvent[ 'lineIndex' ], "Модуль \"" . $eventNameExpl[ 0 ] . "\" не найден, невозможно определить тип обрабатываемого события"  );
							continue;
						}
						
						$eventCreatorScriptData = self::$_scriptsParsedData[ $eventCreatedBy ];
						
						if ( !array_key_exists( $handledEvent[ 'name' ], $eventCreatorScriptData[ 'moduleEvents' ] ) ) {
							// Такого события нет
							self::addError( self::ERR_EVENT_NOT_EXISTS, $scriptPath, $handledEvent[ 'lineIndex' ], "Модуль \"" . $eventNameExpl[ 0 ] . "\" не имеет события \"" . $handledEvent[ 'name' ] . "\"" );
						} else {
							// Такое событие есть, проверяем секцию
							$addEventCalledFunctionIndex = $eventCreatorScriptData[ 'moduleEvents' ][ $handledEvent[ 'name' ] ][ 'calledFunctionIndex' ];
							$addEventLineIndex = $eventCreatorScriptData[ 'calledFunctions' ][ $addEventCalledFunctionIndex ][ 'lineIndex' ];
							$addEventSection = $eventCreatorScriptData[ 'lines' ][ $addEventLineIndex ][ 'section' ];
							if ( $addEventSection != 'Общие события' ) {
								// Событие не открыто для всех
								if ( $addEventSection == 'Внутренние события' ) {
									self::addError( self::ERR_PRIVATE_EVENT_HANDLER, $scriptPath, $handledEvent[ 'lineIndex' ], "Запрещено добавлять обработчики на внутренние события других модулей" );
								} else {
									self::addError( self::ERR_NOSECTION_EVENT_HANDLER, $scriptPath, $handledEvent[ 'lineIndex' ], "Добавлен обработчик на событие другого модуля, которое не имеет определения секции (событие может быть внутренним) #" . $handledEventIndex );
								}
							}
						}
					}
				}
				
				// Вызов функций-обработчиков событий других модулей напрямую
				foreach ( $scriptData[ 'calledFunctions' ] as $calledFunctionIndex => $calledFunctionData ) {
					$functionNameExpl = explode( '.', $calledFunctionData[ 'name' ] );
					
					
					if ( sizeof( $functionNameExpl ) != 1 ) {
						// Функция модуля (в виде aaa.bbb)
						if ( $functionNameExpl[ 0 ] == $scriptData[ 'moduleNameCamel' ] ) {
							// Функция из этого же модуля
							continue; 
						}
						
						$foundFunctionModule = false;
						foreach ( self::$_scriptsParsedData as $sp => $sd ) {
							if ( $sd[ 'moduleNameCamel' ] == $functionNameExpl[ 0 ] ) {
								$foundFunctionModule = true;
								break;
							}
						}
						if ( !$foundFunctionModule ) {
							// Функция из таблицы или стандартного модуля (table/string...)
							continue;
						}
						
						if ( mb_strpos( $calledFunctionData[ 'name' ], ":" ) !== false || mb_strpos( $calledFunctionData[ 'name' ], "]" ) !== false ) {
							// В названии функции есть : или ], это объект или ячейка таблицы - не обрабатываем
							continue; 
						}
						
						$functionCreatedBy = self::getModuleScriptPath( $scriptData[ 'moduleType' ], $functionNameExpl[ 0 ] );
						
						if ( $functionCreatedBy == false || !array_key_exists( $functionCreatedBy, self::$_scriptsParsedData ) ) {
							// Такого модуля нет
							self::addError( self::ERR_FUNCTION_MODULE_NOT_FOUND, $scriptPath, $calledFunctionData[ 'lineIndex' ], "Модуль \"" . $functionNameExpl[ 0 ] . "\" не найден, невозможно определить тип вызываемой функции (\"" . $calledFunctionData[ 'name' ] . "\")"  );
							continue;
						} else {
							// Есть такой модуль
							$functionOwnerScriptData = self::$_scriptsParsedData[ $functionCreatedBy ];
							
							if ( !array_key_exists( $functionNameExpl[ 1 ], $functionOwnerScriptData[ 'moduleFunctions' ] ) ) {
								// Такой функции нет
								self::addError( self::ERR_FUNCTION_NOT_EXISTS, $scriptPath, $calledFunctionData[ 'lineIndex' ], "Модуль \"" . $functionNameExpl[ 0 ] . "\" не имеет функции \"" . $calledFunctionData[ 'name' ] . "\"" );
							} else {
								// Такая функция есть, проверяем ее название
								if ( mb_substr( $functionNameExpl[ 1 ], 0, 1 ) == '_' ) {
									// private-функция (начинается с _)
									self::addError( self::ERR_PRIVATE_FUNCTION_CALL, $scriptPath, $calledFunctionData[ 'lineIndex' ], "Запрещено вызывать внутренние функции других модулей (начинающиеся с _), функция " . $calledFunctionData[ 'name' ] . " является внутренней" );
								} else if ( mb_substr( $functionNameExpl[ 1 ], 0, 2 ) == 'on' && strtoupper( mb_substr( $functionNameExpl[ 1 ], 2, 1 ) ) == mb_substr( $functionNameExpl[ 1 ], 2, 1 ) ) {
									// on[большая буква]
									self::addError( self::ERR_EVENT_HANDLER_FUNCTION_CALL, $scriptPath, $calledFunctionData[ 'lineIndex' ], "Запрещено вызывать функции-обработчики событий других модулей, функция " . $calledFunctionData[ 'name' ] . " является обработчиком события, а не общедоступным методом" );
								}
							}
						}
					}
				}
				
				// Начало каждой секции должно быть выделено комментарием шириной 80 символов (чтобы все выглядело наглядно)
				$currentSectionName = 'Вне секции';
				foreach ( $scriptData[ 'lines' ] as $lineIndex => $lineData ) {
					if ( $lineData[ 'section' ] != $currentSectionName ) {
						// Изменилась секция на этой строке
						if ( $lineIndex != 0 ) {
							// Не первая строка
							$lineBefore = $scriptData[ 'lines' ][ $lineIndex - 1 ][ 'rawSource' ];
							if ( preg_match( '/[^\-]+/u', trim( $lineBefore ) ) ) {
								// Найдено что-то кроме комментария
								self::addError( self::ERR_INVALID_SECTION_COMMENT_FORMAT, $scriptPath, $lineIndex - 1, "Перед строкой, задающей секцию (--<[ ]>--), должна быть только строка, содержащая сплошной комментарий (----)" );
							} else {
								// Сплошной комментарий - считаем длину
								$factLineLength = self::getFactStringLength( $lineBefore );
								if ( $factLineLength != 80 ) {
									self::addError( self::ERR_INVALID_SECTION_COMMENT_FORMAT, $scriptPath, $lineIndex - 1, "Строка должна иметь длину ровно 80 символов и содержать только дефис (сплошной комментарий)" );
								}
							}
						} else {
							// Первая строка
							self::addError( self::ERR_INVALID_SECTION_COMMENT_FORMAT, $scriptPath, $lineIndex, "Строка, которая задает секцию, не должна быть первой в файле, так как она должна быть окружена сплошным комментарием длиной 80 символов" );
						}
						
						$factLineLength = self::getFactStringLength( $lineData[ 'rawSource' ] );
						if ( $factLineLength != 80 ) {
							self::addError( self::ERR_INVALID_SECTION_COMMENT_FORMAT, $scriptPath, $lineIndex, "Строка, которая задает секцию, должна иметь вид \"--<[ Секция ]>------...\" и иметь длину ровно 80 символов" );
						}
						
						if ( $lineIndex + 1 != sizeof( $scriptData[ 'lines' ] ) ) {
							// Не последняя строка
							$lineAfter = $scriptData[ 'lines' ][ $lineIndex + 1 ][ 'rawSource' ];
							if ( preg_match( '/[^\-]+/u', trim( $lineAfter ) ) ) {
								// Найдено что-то кроме комментария
								self::addError( self::ERR_INVALID_SECTION_COMMENT_FORMAT, $scriptPath, $lineIndex + 1, "После строки, задающей секцию (--<[ ]>--), должна быть только строка, содержащая сплошной комментарий (----)" );
							} else {
								// Сплошной комментарий - считаем длину
								$factLineLength = self::getFactStringLength( $lineAfter );
								if ( $factLineLength != 80 ) {
									self::addError( self::ERR_INVALID_SECTION_COMMENT_FORMAT, $scriptPath, $lineIndex + 1, "Строка должна иметь длину ровно 80 символов и содержать только дефис (сплошной комментарий)" );
								}
							}
						} else {
							// Последняя строка
							self::addError( self::ERR_INVALID_SECTION_COMMENT_FORMAT, $scriptPath, $lineIndex, "Строка, которая задает секцию, не должна быть последней в файле, так как она должна быть окружена сплошным комментарием длиной 80 символов" );
						}
						
						$currentSectionName = $lineData[ 'section' ];
					}
				}
				
				// Ищем функции с длиной названия > 31
				/*
				foreach ( self::$_scriptsParsedData as $scriptPath => $scriptData ) {
					foreach ( $scriptData[ 'moduleFunctions' ] as $functionName => $functionData ) {
						if ( strlen( $functionName ) > 31 ) {
							self::addError( self::ERR_TOO_LONG_FUNCTION_NAME, $scriptPath, $functionData[ 'lineIndex' ], "Слишком длинное название функции, максимум 31 символ" );
						}
					}
				}
				*/
				// Ищем русские символы вне строк и комментариев
				preg_match_all( '/[а-яА-ЯёЁїЇєЄіІ]+/u', $scriptData[ 'onelineNostring' ], $matches, PREG_OFFSET_CAPTURE );
				if ( sizeof( $matches[ 0 ] ) != 0 ) {
					foreach ( $matches[ 0 ] as $match ) {
						$lineIndex = self::onestringGetLineIndex( $match[ 1 ], $scriptData[ 'onelineNostring' ], $scriptData[ 'onelineNostringMap' ] );
						self::addError( self::ERR_CYRILLIC_CHARACTER_OUTSIDE_STRING, $scriptPath, $lineIndex, "Символ кирилицы не в строке и не в комментарии: " . $match[ 0 ] );
					}
				}
				
				// Выводим прогресс
				$handledSciptCount++;
				if ( $handledSciptCount != 1 ) {
					for ( $i=0; $i< 20 + 3 + 7; $i++ ) {
						echo chr(8);
					}
				}
				echo sprintf( "[%20s] %3d/%3d", $totalProgressBars, $handledSciptCount, $scriptCount );
			}
			echo "\n";
			
			// Проанализировали, выводим отчет
			self::log( "Source code was inspected, generating report..." );
			
			$totalStats = array(
				'publicFunctions' => 0,
				'publicEvents' => 0,
				'publicFunctionCalls' => 0,
			);
			
			self::reportWrite( '<!DOCTYPE HTML>' );
			self::reportWrite( '<html>' );
			self::reportWrite( '<head>' );
			self::reportWrite( 		'<script>' );
			self::reportWrite( 		'</script>' );
			self::reportWrite( 		file_get_contents( self::ROOT . 'inspector/head.html' ) );
			self::reportWrite( '</head>' );
			self::reportWrite( '<body>' );
			
			self::reportWrite( '	<div id="script-info-item-details-underlay" onClick="hideDetailedScriptItemInfo()"></div>' );
			
			// -- Сортируем список скриптов
			ksort( self::$_scriptsParsedData );
			
			// -- Выводим основной список скриптов
			self::reportWrite( 		'<div id="scripts-wrap">' );
			self::reportWrite( 			'<table id="scripts" cellpadding="0" cellspacing="0">' );
			
			foreach ( self::$_scriptsParsedData as $scriptPath => $scriptData ) {
				self::reportWrite( 			'<tr class="script script-type-' . $scriptData[ 'moduleType' ] . '" id="script-' . $scriptData[ 'scriptID' ] . '">' );
				self::reportWrite( 				'<td class="script-name"><a href="#info:' . $scriptData[ 'scriptID' ] . '">' . $scriptData[ 'moduleNameCamel' ] . '</a></td>' );
				self::reportWrite( 				'<td class="scripts-button script-source-code-button"><a href="#source:' . $scriptData[ 'scriptID' ] . '"><i class="fa fa-code"></i></a></td>' );
				if ( sizeof( $scriptData[ 'errors' ] ) == 0 ) {
					self::reportWrite( 				'<td class="scripts-button script-report-button green"><a href="#report:' . $scriptData[ 'scriptID' ] . '"><i class="fa fa-check"></i></a></td>' );
				} else {
					self::reportWrite( 				'<td class="scripts-button script-report-button"><a href="#report:' . $scriptData[ 'scriptID' ] . '">' . sizeof( $scriptData[ 'errors' ] ) . '</a></td>' );
				}
				if ( sizeof( $scriptData[ 'todo' ] ) == 0 ) {
					self::reportWrite( 				'<td class="scripts-button script-todo-button green"><a href="#todo:' . $scriptData[ 'scriptID' ] . '"><i class="fa fa-check"></i></a></td>' );
				} else {
					self::reportWrite( 				'<td class="scripts-button script-todo-button"><a href="#todo:' . $scriptData[ 'scriptID' ] . '">' . sizeof( $scriptData[ 'todo' ] ) . '</a></td>' );
				}
				self::reportWrite( 			'</tr>' );
			}
			self::reportWrite( 			'</table>' );
			self::reportWrite( 		'</div>' );
			
			// -- Выводим исходный код
			$scriptsRootDir = realpath( str_replace( '\\', '/', __DIR__ . self::ROOT ) );
			foreach ( self::$_scriptsParsedData as $scriptPath => $scriptData ) {
				self::reportWrite( 	'<div class="window script-source" id="script-source-' . $scriptData[ 'scriptID' ] . '">' );
				self::reportWrite( 		'<div class="window-header">' );
				self::reportWrite( 			'<div class="window-header-icon"><i class="fa fa-code"></i></div>' );
				self::reportWrite( 			'<div class="window-header-module">' . $scriptData[ 'moduleNameCamel' ] . '</div>' );
				self::reportWrite( 			'<div class="window-header-path">' . $scriptPath . '</div>' );
				self::reportWrite( 			'<a class="window-header-close-button" href="#"><i class="fa fa-times"></i></a>' );
				self::reportWrite( 		'</div>' );
				self::reportWrite( 		'<div class="window-content">' );
				self::reportWrite( 			'<div class="script-line-numbers">' );
				foreach ( $scriptData[ 'lines' ] as $lineIndex => $lineData ) {
					self::reportWrite( 			'<span class="sl" id="sl-' . $scriptData[ 'scriptID' ] . '-' . $lineIndex . '">' );
					
					// Ищем ошибки на этой строке
					$lineErrors = array();
					foreach ( $scriptData[ 'errors' ] as $idx => $error ) {
						if ( $error[ 'lineIndex' ] == $lineIndex ) {
							$lineErrors[] = $error[ 'message' ];
						}
					}
					if ( sizeof( $lineErrors ) !== 0 ) {
						// На строке есть ошибки
						self::reportWrite( 			'<span class="sl-err">' );
						self::reportWrite( 				'<i class="fa fa-bug"></i>' );
						self::reportWrite( 				'<span>' );
						self::reportWrite( 					'<ul>' );
						foreach ( $lineErrors as $err ) {
							self::reportWrite( 					'<li>' . $err . '</li>' );	
						}
						self::reportWrite( 					'</ul>' );
						self::reportWrite( 				'</span>' );
						self::reportWrite( 			'</span>' );
					}
					$openEditorCMD = '"' . self::NPP_EXE_PATH . '" "' . $scriptsRootDir . '/' . $scriptPath . '" -n' . ( $lineIndex + 1 );
					self::reportWrite( 				'<span class="sl-n"><a href=\'' . self::PRIVATECMDRUN_PROTOCOL . base64_encode( $openEditorCMD ) . '\'>' . ( $lineIndex + 1 ) . '</a></span>' );
					self::reportWrite( 			'</span>' );
				}
				self::reportWrite( 			'</div>' );
				self::reportWrite( 			'<code class="language-lua">' );
				foreach ( $scriptData[ 'lines' ] as $lineIndex => $lineData ) {
					if ( self::INCLUDE_SOURCE_CODE ) {
						$rawSource = htmlspecialchars( $lineData[ 'rawSource' ] );
						
						// Заменяем вызовы функций на ссылки с вызовами функцй
						// Ищем, вызывалась ли какая-то общая функция на этой строке
						foreach ( $scriptData[ 'calledFunctions' ] as $k => $v ) {
							if ( $v[ 'lineIndex' ] == $lineIndex ) {
								// Есть вызов какой-то функции, ищем чья она
								$nameExpl = explode( '.', $v[ 'name' ] );
								if ( sizeof( $nameExpl ) == 1 ) continue; // Ничья (без точки) TODO https://wiki.multitheftauto.com/wiki/EngineImportTXD
								
								$sp = false;
								if ( $scriptData[ 'moduleType' ] == 'shared' ) {
									$sp = self::getModuleScriptPath( 'client', $nameExpl[ 0 ] );
									if ( !$sp ) {
										$sp = self::getModuleScriptPath( 'server', $nameExpl[ 0 ] );
									}
								} else {
									$sp = self::getModuleScriptPath( $scriptData[ 'moduleType' ], $nameExpl[ 0 ] );
									if ( !$sp ) {
										$sp = self::getModuleScriptPath( 'shared', $nameExpl[ 0 ] );
									}
								}
								
								if ( !$sp ) {
									// Не нашлось
									continue;
								}
								
								$otherScriptData = self::$_scriptsParsedData[ $sp ];
								
								$fname = $nameExpl[ 1 ];
								
								$rawSource = str_replace( $v[ 'name' ], '<a href="javascript:showDetailedScriptItemInfo(\'script-info-details-' . $otherScriptData[ 'scriptID' ] . '-f-' . $fname . '\')">' . $v[ 'name' ] . '</a>', $rawSource );
							}
						}
						
						self::reportWrite( 			$rawSource );
					} else {
						self::reportWrite( 			htmlspecialchars( self::obfuscateSourceLine( $lineData[ 'rawSource' ] ) ) );
					}
				}
				self::reportWrite( 			'</code>' );
				self::reportWrite( 		'</div>' );
				self::reportWrite( 	'</div>' );
			}
			
			// -- Выводим отчет об ошибках
			foreach ( self::$_scriptsParsedData as $scriptPath => $scriptData ) {
				self::reportWrite( 	'<div class="window script-report" id="script-report-' . $scriptData[ 'scriptID' ] . '">' );
				self::reportWrite( 		'<div class="window-header">' );
				self::reportWrite( 			'<div class="window-header-icon"><i class="fa fa-bug"></i></div>' );
				self::reportWrite( 			'<div class="window-header-module">' . $scriptData[ 'moduleNameCamel' ] . '</div>' );
				self::reportWrite( 			'<div class="window-header-path">' . $scriptPath . '</div>' );
				self::reportWrite( 			'<a class="window-header-close-button" href="#"><i class="fa fa-times"></i></a>' );
				self::reportWrite( 		'</div>' );
				self::reportWrite( 		'<div class="window-content">' );
				if ( sizeof( $scriptData[ 'errors' ] ) == 0 ) {
					self::reportWrite( 		'<div class="script-report-content-noerrors"><i class="fa fa-thumbs-up"></i><span>Ошибки не найдены</span></div>' );
				} else {
					foreach ( $scriptData[ 'errors' ] as $error ) {
						$errorLineSource = self::$_scriptsParsedData[ $scriptPath ][ 'lines' ][ $error[ 'lineIndex' ] ][ 'rawSource' ];
						self::reportWrite( 	'<a class="script-report-item" href="#source:' . $scriptData[ 'scriptID' ] . ':' . $error[ 'lineIndex' ] . '">' );
						self::reportWrite( 		'<span class="script-report-item-message"><i class="fa fa-bug"></i>#' . sprintf( '%X', $error[ 'errorCode' ] ) . ' : ' . $error[ 'message' ] . '</span>' );
						self::reportWrite( 		'<span class="script-report-item-line">' . ( $error[ 'lineIndex' ] + 1 ) . '</span>' );
						self::reportWrite( 		'<span class="script-report-item-source"><code class="language-lua">' . htmlspecialchars( $errorLineSource ) . '</code></span>' );
						self::reportWrite( 	'</a>' );
					}
				}
				self::reportWrite( 		'</div>' );
				self::reportWrite( 	'</div>' );
			}
			
			// -- Выводим TODO
			foreach ( self::$_scriptsParsedData as $scriptPath => $scriptData ) {
				self::reportWrite( 	'<div class="window script-todo" id="script-todo-' . $scriptData[ 'scriptID' ] . '">' );
				self::reportWrite( 		'<div class="window-header">' );
				self::reportWrite( 			'<div class="window-header-icon"><i class="fa fa-sticky-note"></i></div>' );
				self::reportWrite( 			'<div class="window-header-module">' . $scriptData[ 'moduleNameCamel' ] . '</div>' );
				self::reportWrite( 			'<div class="window-header-path">' . $scriptPath . '</div>' );
				self::reportWrite( 			'<a class="window-header-close-button" href="#"><i class="fa fa-times"></i></a>' );
				self::reportWrite( 		'</div>' );
				self::reportWrite( 		'<div class="window-content">' );
				if ( sizeof( $scriptData[ 'todo' ] ) == 0 ) {
					self::reportWrite( 		'<div class="script-todo-content-notodo"><i class="fa fa-thumbs-up"></i><span>Пунктов TODO не найдено</span></div>' );
				} else {
					foreach ( $scriptData[ 'todo' ] as $todo ) {
						$todoLineSource = self::$_scriptsParsedData[ $scriptPath ][ 'lines' ][ $todo[ 'lineIndex' ] ][ 'rawSource' ];
						self::reportWrite( 	'<a class="script-todo-item" href="#source:' . $scriptData[ 'scriptID' ] . ':' . $todo[ 'lineIndex' ] . '">' );
						self::reportWrite( 		'<span class="script-todo-item-message">' . $todo[ 'message' ] . '</span>' );
						self::reportWrite( 		'<span class="script-todo-item-line">' . ( $todo[ 'lineIndex' ] + 1 ) . '</span>' );
						self::reportWrite( 		'<span class="script-todo-item-source"><code class="language-lua">' . htmlspecialchars( $todoLineSource ) . '</code></span>' );
						self::reportWrite( 	'</a>' );
					}
				}
				self::reportWrite( 		'</div>' );
				self::reportWrite( 	'</div>' );
			}
			
			// -- Выводим общую информацию каждого скрипта
			foreach ( self::$_scriptsParsedData as $scriptPath => $scriptData ) {
				self::reportWrite( 	'<div class="window script-info" id="script-info-' . $scriptData[ 'scriptID' ] . '">' );
				self::reportWrite( 		'<div class="window-header">' );
				self::reportWrite( 			'<div class="window-header-icon"><i class="fa fa-info"></i></div>' );
				self::reportWrite( 			'<div class="window-header-module">' . $scriptData[ 'moduleNameCamel' ] . '</div>' );
				self::reportWrite( 			'<div class="window-header-path">' . $scriptPath . '</div>' );
				self::reportWrite( 			'<a class="window-header-close-button" href="#"><i class="fa fa-times"></i></a>' );
				self::reportWrite( 		'</div>' );
				self::reportWrite( 		'<div class="window-content">' );
				
				// Функции
				self::reportWrite( 			'<div class="script-info-mainblock-wrap">' );
				self::reportWrite( 				'<div class="script-info-mainblock-title">' );
				self::reportWrite( 					'Функции' );
				self::reportWrite( 				'</div>' );
				self::reportWrite( 				'<div class="script-info-mainblock mainblock-type-functions">' );
				
				$functions = $scriptData[ 'moduleFunctions' ];
				ksort( $functions );
				$listedFunctionsCount = 0;
				
				$lastFirstLetter = '';
				
				foreach ( $functions as $functionName => $functionData ) {
					if ( 
						$functionName == 'init' 
						|| mb_substr( $functionName, 0, 1 ) == '_' 
						|| ( 
							mb_substr( $functionName, 0, 2 ) == 'on' 
							&& mb_substr( $functionName, 2, 1 ) == strtoupper( mb_substr( $functionName, 2, 1 ) ) 
							) 
					) continue;
					
					// Общая функция
					$totalStats[ 'publicFunctions' ]++;
					
					$curFirstLetter = strtoupper( mb_substr( $functionName, 0, 1 ) );
					if ( $lastFirstLetter != $curFirstLetter ) {
						$lastFirstLetter = $curFirstLetter;
						self::reportWrite( '<div class="script-info-first-letter-separator" data-content="' . $curFirstLetter . '"></div>' );
					}
					
					$functionArgsString = '';
					foreach ( $functionData[ 'description' ][ 'args' ] as $argIndex => $arg ) {
						if ( $arg[ 'name' ] == 'self' && $argIndex == 0 ) continue;
						
						$dataTypesString = htmlspecialchars( implode( ' / ', $arg[ 'dataTypes' ] ) );
						$functionArgsString .= '<span class="arg"><span class="data-types" data-content="' . $dataTypesString . '"></span><span class="name">' . $arg[ 'name' ] . '</span></span>';
						if ( $argIndex + 1 != sizeof( $functionData[ 'description' ][ 'args' ] ) ) {
							$functionArgsString .= ', ';
						}
					}
					if ( mb_strlen( $functionArgsString ) != 0 ) {
						$functionArgsString = ' ' . $functionArgsString . ' ';
					}
					
					$functionReturnString = '';
					if ( gettype( $functionData[ 'description' ][ 'return' ] ) == 'array' ) { 
						foreach ( $functionData[ 'description' ][ 'return' ] as $returnIndex => $item ) {
							$dataTypesString = htmlspecialchars( implode( ' / ', $item[ 'dataTypes' ] ) );
							$functionReturnString .= '<span class="return"><span class="data-types" data-content="' . $dataTypesString . '"></span><span class="name">' . $item[ 'name' ] . '</span></span>';
							if ( $returnIndex + 1 != sizeof( $functionData[ 'description' ][ 'return' ] ) ) {
								$functionReturnString .= ', ';
							}
						}
					} else {
						$functionReturnString = '<span class="return-void">void<span>';
					}
					
					$functionCallType = '.';
					if ( sizeof( $functionData[ 'description' ][ 'args' ] ) != 0 && $functionData[ 'description' ][ 'args' ][ 0 ][ 'name' ] == 'self' ) {
						$functionCallType = ':';
					}
					
					self::reportWrite( 				'<div class="script-info-item script-info-item-type-' . ( $functionCallType == ':' ? 'object' : 'static' ) . ' function-type-' . $scriptData[ 'moduleType' ] . '">' );
					self::reportWrite( 					'<div class="script-info-item-syntax" contenteditable="true">' );
					self::reportWrite( 						'<span class="function-name">' );
					if ( $functionCallType == ':' ) {
						// Запрещаем выделение префикса (объекты никогда не будут называтся как классы, выделять это никто не будет)
						self::reportWrite( 							'<span class="function-name-module-prefix function-name-module-prefix-unselectable" data-content="' . $scriptData[ 'moduleNameCamel' ] . '"></span>' );
					} else {
						self::reportWrite( 							'<span class="function-name-module-prefix">' . $scriptData[ 'moduleNameCamel' ] . '</span>' );
					}
					self::reportWrite( 							$functionCallType . $functionName );
					self::reportWrite(						'</span>' );
					self::reportWrite( 						'<span class="args">(' . $functionArgsString . ')</span>' );
					self::reportWrite( 					'</div>' );
					self::reportWrite( 					'<span class="script-info-details-button" onClick="showDetailedScriptItemInfo(\'script-info-details-' . $scriptData[ 'scriptID' ] . '-f-' . $functionName . '\')"><i class="fa fa-info-circle"></i></span>' );
					self::reportWrite( 					'<span class="script-info-returns" contenteditable="true"><i class="fa fa-chevron-right"></i>' . $functionReturnString . '</span>' );
					self::reportWrite( 				'</div>' );
					
					// Подробная информация
					self::reportWrite( 				'<div class="script-info-item-details module-type-' . $scriptData[ 'moduleType' ] . ' item-type-function" id="script-info-details-' . $scriptData[ 'scriptID' ] . '-f-' . $functionName . '">' );
					self::reportWrite( 					'<h2>' . $scriptData[ 'moduleNameCamel' ] . $functionCallType . $functionName . '</h2>' );
					self::reportWrite( 					'<a class="details-item-declaration-script-link" href="#source:' . $scriptData[ 'scriptID' ] . ':' . $functionData[ 'lineIndex' ] . '" title="Перейти на строку оглашения функции"><i class="fa fa-code"></i></a>' );
					self::reportWrite( 					'<div class="details-description">' . implode( '<br>', array_reverse( $functionData[ 'description' ][ 'brief' ] ) ) . '</div>' );
					
					$functionArgsStringSquareBrackets = '';
					$inOptionalArgs = false;
					foreach ( $functionData[ 'description' ][ 'args' ] as $argIndex => $arg ) {
						if ( $arg[ 'name' ] == 'self' && $argIndex == 0 ) continue;
						
						if ( in_array( 'nil', $arg[ 'dataTypes' ] ) ) {
							if ( !$inOptionalArgs ) {
								$inOptionalArgs = true;
								$functionArgsStringSquareBrackets .= '<span class="optional-brackets">[</span><span class="optional">';
							}
						} else {
							if ( $inOptionalArgs ) {
								$inOptionalArgs = false;
								$functionArgsStringSquareBrackets .= '</span><span class="optional-brackets">]</span>';
							}
						}
						$dataTypesString = htmlspecialchars( implode( ' / ', $arg[ 'dataTypes' ] ) );
						$functionArgsStringSquareBrackets .= '<span class="arg"><span class="data-types" data-content="' . $dataTypesString . '"></span><span class="name">' . $arg[ 'name' ] . '</span></span>';
						if ( $argIndex + 1 != sizeof( $functionData[ 'description' ][ 'args' ] ) ) {
							$functionArgsStringSquareBrackets .= ', ';
						}
					}
					if ( $inOptionalArgs ) {
						$functionArgsStringSquareBrackets .= '</span><span class="optional-brackets">]</span>';
					}
					if ( mb_strlen( $functionArgsStringSquareBrackets ) != 0 ) {
						$functionArgsStringSquareBrackets = ' ' . $functionArgsStringSquareBrackets . ' ';
					}
					
					self::reportWrite( 					'<h3>Синтаксис</h3>' );
					self::reportWrite( 					'<div class="details-syntax">' );
					self::reportWrite( 						'<span class="function-name">' );
					self::reportWrite( 							$scriptData[ 'moduleNameCamel' ] . $functionCallType . $functionName );
					self::reportWrite(						'</span>' );
					self::reportWrite( 						'<span class="args">(' . $functionArgsStringSquareBrackets . ')</span>' );
					self::reportWrite( 					'</div>' );
					
					if ( sizeof( $functionData[ 'description' ][ 'args' ] ) != 0 ) {
						self::reportWrite( 					'<table class="details-arguments" cellpadding="0" cellspacing="0">' );
						foreach ( $functionData[ 'description' ][ 'args' ] as $argIndex => $arg ) {
							if ( $arg[ 'name' ] == 'self' && $argIndex == 0 ) continue;
							
							self::reportWrite( 					'<tr ' . ( in_array( 'nil', $arg[ 'dataTypes' ] ) ? '' : 'class="mandatory"' ) . '>' );
							self::reportWrite( 						'<td class="data-types">' );
							self::reportWrite( 							implode( '<br>', $arg[ 'dataTypes' ] ) );
							self::reportWrite( 						'</td>' );
							self::reportWrite( 						'<td class="name">' . $arg[ 'name' ] . '</td>' );
							self::reportWrite( 						'<td class="description">' . htmlspecialchars( $arg[ 'description' ] ) . '</td>' );
							self::reportWrite( 					'</tr>' );
						}
						self::reportWrite( 					'</table>' );
					}
					
					self::reportWrite( 					'<h3>Возвращаемые значения</h3>' );
					if ( $functionData[ 'description' ][ 'return' ] != false ) {
						self::reportWrite( 				'<div class="returns-summary">' . $functionReturnString . '</div>' );
						self::reportWrite( 				'<table class="details-returns" cellpadding="0" cellspacing="0">' );
						foreach ( $functionData[ 'description' ][ 'return' ] as $argIndex => $arg ) {
							self::reportWrite( 				'<tr>' );
							self::reportWrite( 					'<td class="data-types">' );
							self::reportWrite( 						implode( '<br>', $arg[ 'dataTypes' ] ) );
							self::reportWrite( 					'</td>' );
							self::reportWrite( 					'<td class="name">' . $arg[ 'name' ] . '</td>' );
							self::reportWrite( 				'</tr>' );
						}
						self::reportWrite( 				'</table>' );
					} else {
						self::reportWrite( 				'<div class="returns-summary-void">Функция не возвращает ничего</div>' );
					}
					
					if ( $functionCallType != ':' ) {
						self::reportWrite( 					'<div class="details-used">' );
						self::reportWrite( 						'<h3>Список скриптов, в которых использована функция</h3>' );
						
						$cnt = 0;
						foreach ( self::$_scriptsParsedData as $otherScriptPath => $otherScriptData ) {
							if ( $scriptData[ 'moduleType' ] == 'shared' || ( $otherScriptData[ 'moduleType' ] == $scriptData[ 'moduleType' ] || $otherScriptData[ 'moduleType' ] == 'shared' ) ) {
								// Скрипт в одном пространстве с текущим
								foreach ( $otherScriptData[ 'calledFunctions' ] as $calledFunctionIndex => $calledFunctionData ) {
									if ( 
										( $calledFunctionData[ 'name' ] == $scriptData[ 'moduleNameCamel' ] . '.' . $functionName ) // Прямое название функции
										|| ( $functionName == 'create' && $calledFunctionData[ 'name' ] == $scriptData[ 'moduleNameCamel' ] ) // Module() == Module.create()
									) {
										self::reportWrite( 			'<a class="' . $otherScriptData[ 'moduleType' ] . '" href="#source:' . $otherScriptData[ 'scriptID' ] . ':' . ( $calledFunctionData[ 'lineIndex' ] ) . '"><span class="module-name">' . $otherScriptData[ 'moduleNameCamel' ] . '</span>' . $otherScriptPath . ', строка: ' . ( $calledFunctionData[ 'lineIndex' ] + 1 ) . '</a>' );
										
										$totalStats[ 'publicFunctionCalls' ]++;
										
										$cnt++;
									} else {
										// self::log( $otherScriptPath . ':' . ( $calledFunctionData[ 'lineIndex' ] + 1 ) . ' ' . $calledFunctionData[ 'name' ] . ' | ' . $scriptData[ 'moduleNameCamel' ] . '.' . $functionName );
									}
								}
							}
						}
						if ( $cnt == 0 ) {
							self::reportWrite( 					'Функция нигде не использовалась' );
						}
						
						self::reportWrite( 					'</div>' );
					}
					
					self::reportWrite( 					'</div>' );
					
					$listedFunctionsCount++;
				}
				
				if ( $listedFunctionsCount == 0 ) {
					self::reportWrite( 					'<div class="script-info-mainblock-empty">Модуль не имеет общих функций</div>' );
				}
				
				self::reportWrite( 				'</div>' );
				self::reportWrite( 			'</div>' );
				
				// События
				$totalStats[ 'publicEvents' ]++;
					
				self::reportWrite( 			'<div class="script-info-mainblock-wrap">' );
				self::reportWrite( 				'<div class="script-info-mainblock-title">' );
				self::reportWrite( 					'События' );
				self::reportWrite( 				'</div>' );
				self::reportWrite( 				'<div class="script-info-mainblock mainblock-type-events">' );
				
				$events = $scriptData[ 'moduleEvents' ];
				ksort( $events );
				$listedEventCount = 0;
				
				foreach ( $events as $eventName => $eventData ) {
					if ( $scriptData[ 'lines' ][ $scriptData[ 'calledFunctions' ][ $eventData[ 'calledFunctionIndex' ] ][ 'lineIndex' ] ][ 'section' ] != 'Общие события' ) {
						continue;
					}
					
					self::reportWrite( 				'<div class="script-info-item">' );
					self::reportWrite( 					$eventName );
					self::reportWrite( 				'</div>' );
					
					$listedEventCount++;
				}
				
				if ( $listedEventCount == 0 ) {
					self::reportWrite( 					'<div class="script-info-mainblock-empty">Модуль не имеет общих событий</div>' );
				}
				
				self::reportWrite( 				'</div>' );
				self::reportWrite( 			'</div>' );
				
				self::reportWrite( 		'</div>' );
				self::reportWrite( 	'</div>' );
			}
			
			self::reportWrite( 		'<div id="footer">' );
			self::reportWrite( 			'<span class="item">' );
			self::reportWrite( 				'<span class="title">Сгенерировано</span>' );
			self::reportWrite( 				'<span class="value">' . date( 'd.m.Y в H:i' ) . '</span>' );
			self::reportWrite( 			'</span>' );
			self::reportWrite( 			'<span class="item">' );
			self::reportWrite( 				'<span class="title">Версия</span>' );
			$ret = array();
			exec( 'git log -1 --pretty=%B', $ret );
			self::reportWrite( 				'<span class="value">' . implode( '', $ret ) . '</span>' );
			self::reportWrite( 			'</span>' );
			self::reportWrite( 			'<span class="item">' );
			self::reportWrite( 				'<span class="title">Функций</span>' );
			self::reportWrite( 				'<span class="value">' . $totalStats[ 'publicFunctions' ] . '</span>' );
			self::reportWrite( 			'</span>' );
			self::reportWrite( 			'<span class="item">' );
			self::reportWrite( 				'<span class="title">Событий</span>' );
			self::reportWrite( 				'<span class="value">' . $totalStats[ 'publicEvents' ] . '</span>' );
			self::reportWrite( 			'</span>' );
			self::reportWrite( 			'<span class="item">' );
			self::reportWrite( 				'<span class="title">Вызовов функций</span>' );
			self::reportWrite( 				'<span class="value">' . $totalStats[ 'publicFunctionCalls' ] . '</span>' );
			self::reportWrite( 			'</span>' );
			self::reportWrite( 		'</div>' );
			
			self::reportWrite( '</body>' );
			self::reportWrite( '</html>' );
			
			self::log( "Report generated, everything is done" );
			
			echo "\n";
		}
		
		// Достает всю информацию из lua-файла и возвращает массив
		private static function parseScript( $scriptPath ) {
			if ( array_key_exists( $scriptPath, self::$_scriptsParsedData ) ) {
				return self::$_scriptsParsedData[ $scriptPath ];
			}

			// Ищем кэш в файле
			$scriptContents = file_get_contents( self::ROOT . $scriptPath );
			$cacheHash = substr( md5( $scriptContents ), 0, 8 );
			if ( file_exists( self::ROOT . 'inspector/cache/' . $cacheHash . '.json' ) ) {
				self::$_scriptsParsedData[ $scriptPath ] = json_decode( file_get_contents( self::ROOT . 'inspector/cache/' . $cacheHash . '.json' ), true );
				
				return self::$_scriptsParsedData[ $scriptPath ];
			}
			
			$scriptLines = self::getScriptContents( $scriptPath );
			
			self::$_scriptsParsedData[ $scriptPath ][ 'errors' ] = array();
			self::$_scriptsParsedData[ $scriptPath ][ 'todo' ] = array();
			
			$lines = array();
			
			$currentSection = 'Вне секции';
			$currentLine = 1;
			$inMultilineComment = false;
			
			// Находим секции скрипта, ищем комментарии
			$comments = array();
			foreach ( $scriptLines as $sourceLine ) {
				$lineData = array();
				$line = trim( $sourceLine );
				
				$lineIndex = $currentLine - 1;
				
				$lineData[ 'tabSize' ] = 0; // tab size (4 spaces == 1 tab)
				$lineData[ 'lineNumber' ] = $currentLine; // number (index + 1)
				$lineData[ 'rawSource' ] = $sourceLine; // source code (raw, with comments)
				$lineData[ 'source' ] = $line; // source code (without comments)
				//$lineData[ 'sourceSemicolon' ] // source code (without comments, with ;)
				$lineData[ 'inMultilineComment' ] = $inMultilineComment; // in multiline comment
				$lineData[ 'section' ] = $currentSection; // current section
				
				if ( mb_substr( $line, 0, 2 ) == '--' && mb_strpos( $line, "<[" ) !== false ) {
					// Начало новой секции
					preg_match( '/\<\[([^\]]+)/u', $line, $matches );
					if ( sizeof( $matches ) != 0 ) {
						$currentSection = trim( $matches[ 1 ] );
						$lineData[ 'section' ] = $currentSection;
						$line = '';
					}
				} else {
					$lineNoStrings = self::lineWithoutStrings( $scriptPath, $lineIndex, $line );
					if ( $inMultilineComment ) {
						// Внутри многострочного комментария
						$endCommentPos = mb_strpos( $lineNoStrings, ']]' );
						if ( $endCommentPos !== false ) {
							// Найдены закрывающие скобки комментария
							$inMultilineComment = false;
							
							// Ищем текст после закрывающих скобок
							if ( trim( mb_substr( $lineNoStrings, $endCommentPos + 2 ) ) != '' ) {
								self::addError( self::ERR_CODE_AFTER_MULTILINE_COMMENT, $scriptPath, $lineIndex, "Код в строке после закрытия многострочного комментария запрещен: \"" . trim( mb_substr( $lineNoStrings, $endCommentPos + 2 ) ) . "\"" );
							}
						}
						$comments[ $lineIndex ] = rtrim( $sourceLine );
						$line = '';
					} else {
						// Не в многострочном комментарии
						$startCommentPos = mb_strpos( $lineNoStrings, '--[[' );
						$multilineCommentClosedSameLine = false;
						if ( $startCommentPos === 0 ) {
							// Найдено начало многострочного комментария в начале строки
							$inMultilineComment = true;
							$endCommentPos = mb_strpos( $lineNoStrings, ']]', $startCommentPos );
							if ( $endCommentPos !== false ) {
								// Конец на той же строке
								$inMultilineComment = false;
								$multilineCommentClosedSameLine = true;
								
								$comments[ $lineIndex ] = mb_substr( trim( $lineNoStrings ), $startCommentPos, $endCommentPos - $startCommentPos );
								
								// Ищем текст после закрывающих скобок
								if ( trim( mb_substr( $lineNoStrings, $endCommentPos + 2 ) ) != '' ) {
									self::addError( self::ERR_CODE_AFTER_MULTILINE_COMMENT, $scriptPath, $lineIndex, "Код в строке после закрытия многострочного комментария запрещен: \"" . trim( mb_substr( $lineNoStrings, $endCommentPos + 2 ) ) . "\"" );
								}
							} else {
								// Конец не на этой же строке
								$comments[ $lineIndex ] = mb_substr( trim( $lineNoStrings ), $startCommentPos );
							}
							$lineData[ 'inMultilineComment' ] = $inMultilineComment;
							$line = '';
						} else if ( $startCommentPos !== false ) {
							// Многострочный комментарий начинается после кода
							self::addError( self::ERR_MULTILINE_COMMENT_AFTER_CODE, $scriptPath, $lineIndex, "Многострочный комментарий не должен начинаться после кода" );
						}					
						
						if ( !$inMultilineComment ) {
							// Код (не многострочный комментарий)
							$commentPos = mb_strpos( $lineNoStrings, '--' );
							if ( $commentPos !== false ) {
								// Найден однострочный комментарий
								// commentPos - позиция в строке без lua-строк
								// Ищем начало комментария с конца (последний символ до " или ')
								// Было: $line = trim( mb_substr( $line, 0, $commentPos ) );
								$chars = self::getStringChars( $line );
								$lastSymbolIsHyphen = false;
								$lastCommentStartSeen = -1;
								$inQuotes = false;
								for ( $i = sizeof( $chars ) - 1; $i >= 0; $i-- ) {
									if ( !$inQuotes && $lastSymbolIsHyphen ) {
										// Последним было -, не в строке
										if ( $chars[ $i ] == '-' ) {
											// И сейчас -, смещаем комментарий
											$lastCommentStartSeen = $i;
										}
									}
									
									if ( $lastCommentStartSeen != -1 && ( $chars[ $i ] == '"' || $chars[ $i ] == "'" ) ) {
										// Строка - внутри никаких комментариев
										$inQuotes = !$inQuotes;
									}
									
									$lastSymbolIsHyphen = ( $chars[ $i ] == '-' );
								}
								
								if ( $lastCommentStartSeen != -1 ) {
									// Обрезаем до комментария
									$cmnt = trim( mb_substr( $line, $lastCommentStartSeen ) );
									if ( $cmnt != '' ) {
										$comments[ $lineIndex ] = $cmnt;
									}
									$line = trim( mb_substr( $line, 0, $lastCommentStartSeen ) );
								} else {
									// Не найдено и не многострочный комментарий - возможно, это многострочный комментарий, который закрывается на этой же строке
									if ( $multilineCommentClosedSameLine ) {
										// Многострочный комментарий, закрывается на этой же строке и кроме него ничего нет
									} else {
										// Что-то другое
										self::addError( self::ERR_WRONG_COMMENT_USAGE, $scriptPath, $lineIndex, 'Ошибка использования комментариев' );
									}
								}
							}
							if ( $line != '' ) {
								// Не пустая строка
								
								// Считаем кол-во tab в начале строки
								$lineData[ 'tabSize' ] = self::getLineTabSize( $sourceLine );
							}
						}
					}
				}
				
				$lineData[ 'source' ] = $line;
				
				$lines[ $currentLine - 1 ] = $lineData;
				
				$currentLine++;
			}
			self::$_scriptsParsedData[ $scriptPath ][ 'comments' ] = $comments;
			
			// Находим название и тип модуля
			$scriptPathExpl = explode( '/', $scriptPath );
			self::$_scriptsParsedData[ $scriptPath ][ 'moduleType' ] = $scriptPathExpl[ 0 ];
			
			$moduleNameCamel = '';
			
			foreach ( $lines as $line ) {
				if ( mb_substr( $line[ 'section' ], 0, 7 ) == "Модуль " ) {
					$moduleNameCamel = trim( mb_substr( $line[ 'section' ], 7 ) );
					break;
				}
			}
			
			if ( $moduleNameCamel == '' ) {
				// Название модуля не указано
				$moduleNameCamel = rtrim( $scriptPathExpl[ 1 ], ".lua" );
				self::addError( self::ERR_MODULE_NAME_NOT_DEFINED, $scriptPath, 0, "Название (таблицы) модуля не указано. Необходимо задать название модуля с помощью строки \"--<[ Модуль ModuleName ]>\" перед началом таблицы модуля" );
			}
			self::$_scriptsParsedData[ $scriptPath ][ 'moduleNameCamel' ] = $moduleNameCamel;
			self::$_scriptsParsedData[ $scriptPath ][ 'scriptID' ] = self::$_scriptsParsedData[ $scriptPath ][ 'moduleType' ] . self::$_scriptsParsedData[ $scriptPath ][ 'moduleNameCamel' ];
			
			// Ищем TODO в комментариях
			foreach ( $comments as $lineIndex => $commentText ) {
				$todoPos = mb_stripos( $commentText, 'todo' );
				if ( $todoPos !== false ) {
					self::addTODO( $scriptPath, $lineIndex, trim( mb_substr( $commentText, $todoPos + 4 ) ) );
				}
			}
			
			// Сбиваем код в одну строку
			// -- Сначала добавим ; в конец каждой строки, если его еще нет
			foreach ( $lines as $lineIndex => $lineData ) {
				if ( $lineData[ 'source' ] != '' ) {
					// Не пустая строка
					$line = $lineData[ 'source' ];
					
					if ( mb_substr( $line, -1 ) != ';' ) {
						// Еще нет точки с запятой
						if ( mb_substr( $line, -1 ) != '{' ) {
							// Не начало таблицы
							// Проходимся по предопределенным символам, после которых нельзя ставить ;
							$noSemicolumn = array_merge( self::$_predefinedKeywords, self::$_predefinedOperators );
							$isPredefinedWord = false;
							foreach ( $noSemicolumn as $predefinedWord ) {
								if ( mb_substr( $line, -( mb_strlen( $predefinedWord ) ) ) == $predefinedWord ) {
									$isPredefinedWord = true;
									break;
								}
							}
							
							if ( !$isPredefinedWord ) {
								// Не предопределенное слово
								if ( !self::isFunctionDeclarationString( $line ) ) {
									// Не определение функции
									$line .= ';';
								}
							}
						}
					}
					$lines[ $lineIndex ][ 'sourceSemicolon' ] = $line;
				} else {
					$lines[ $lineIndex ][ 'sourceSemicolon' ] = '';
				}
			}
			
			// Генерируем скрипт в одну строку и создаем карту
			$oneline = '';
			$onelineMap = array();		// lineIndex => length
			foreach ( $lines as $lineIndex => $lineData ) {
				$concat = trim( rtrim( $lineData[ 'sourceSemicolon' ], "\\" ) ) . " ";
				$onelineMap[ $lineIndex ] = mb_strlen( $concat );
				
				$oneline .= $concat;
			}
			self::$_scriptsParsedData[ $scriptPath ][ 'lines' ] = $lines;
			self::$_scriptsParsedData[ $scriptPath ][ 'oneline' ] = $oneline;
			self::$_scriptsParsedData[ $scriptPath ][ 'onelineMap' ] = $onelineMap;
			
			// Еще раз в одну строку, но с заменой строк на _STR_ (сразу разделаемся с ", ' и \)
			// Строки выносятся в $data[ 'strings' ]
			$onelineNostring = '';
			$onelineNostringMap = array();	// lineIndex => pos
			$strings = array();
			$escaped = false;
			$inDoubleQuote = false;
			$inSingleQuote = false;
			$stringAccumulator = '';
			$accumStrIndex = 1;
			$chars = self::getStringChars( $oneline );
			$lastLineIndex = 0;
			$currentLineLength = 0;
			for ( $i=0; $i<sizeof( $chars ); $i++ ) {
				$lineIndex = self::onestringGetLineIndex( $i, $oneline, $onelineMap );
				
				if ( $lastLineIndex != $lineIndex ) {
					$onelineNostringMap[ $lastLineIndex ] = $currentLineLength;
					$currentLineLength = 0;
					$lastLineIndex = $lineIndex;
				}
								
				$c = $chars[ $i ];
				if ( $escaped ) {
					$escaped = false;
				} else {
					if ( $c == "\\" ) {
						$escaped = true;
					} else {
						if ( $inSingleQuote ) {
							// Внутри ''
							if ( $c == "'" ) {
								// Конец ''
								$strings[ $accumStrIndex ] = array(
									'string' => $stringAccumulator,
									'quote' => "'",
									'lineIndex' => $lineIndex,
								);
								$inSingleQuote = false;
								$accumStrIndex++;
							} else {
								$stringAccumulator .= $c;
							}
						} else {
							// Не внутри ''
							if ( $inDoubleQuote ) {
								// Внутри ""
								if ( $c == '"' ) {
									// Конец ""
									$strings[ $accumStrIndex ] = array(
										'string' => $stringAccumulator,
										'quote' => '"',
										'lineIndex' => $lineIndex,
									);
									$inDoubleQuote = false;
									$accumStrIndex++;
								} else {
									$stringAccumulator .= $c;
								}
							} else {
								// Не внутри ""
								$addedLen = 0;
								if ( $c == "'" ) {
									// Начало ''
									$stringAccumulator = '';
									$inSingleQuote = true;
									$addStr = '__S' . $accumStrIndex;
									$onelineNostring .= $addStr;
									$addedLen = mb_strlen( $addStr );
								} else if ( $c == '"' ) {
									// Начало ""
									$stringAccumulator = '';
									$inDoubleQuote = true;
									$addStr = '__S' . $accumStrIndex;
									$onelineNostring .= $addStr;
									$addedLen = mb_strlen( $addStr );
								} else {
									// Обычный символ
									$onelineNostring .= $c;
									$addedLen = 1;
								}
								$currentLineLength += $addedLen;
							}
						}
					}
				}
			}
			$onelineNostringMap[ $lastLineIndex ] = $currentLineLength;
			
			self::$_scriptsParsedData[ $scriptPath ][ 'strings' ] = $strings;
			self::$_scriptsParsedData[ $scriptPath ][ 'onelineNostringMap' ] = $onelineNostringMap;
			self::$_scriptsParsedData[ $scriptPath ][ 'onelineNostring' ] = $onelineNostring;
			
			// Создаем рабочий скрипт для onelineNostring (сначала пишем все строки, а потом код)
			$onelineNostringWorking = 'local __S={';
			$stringsCount = sizeof( $strings );
			foreach ( $strings as $i => $str ) {
				$onelineNostringWorking .= $str[ 'quote' ] . $str[ 'string' ] . $str[ 'quote' ];
				if ( $stringsCount - 1 != $i ) {
					$onelineNostringWorking .= ',';
				}
			}
			$onelineNostringWorking .= '};';
			$onelineNostringWorking .= preg_replace( '/__S([\d]+)/', '__S[${1}]', $onelineNostring );
			self::$_scriptsParsedData[ $scriptPath ][ 'onelineNostringWorking' ] = $onelineNostring;
			
			
			// Ищем вызываемые функции
			$chars = self::getStringChars( $onelineNostring );
			$totalChars = sizeof( $chars );
			$charPos = 0;
			$buffer = '';
			$bracketLevel = 0;
			$bracketsStart = -1;
			$rootCalledFunctions = array();
			$lastWasSpace = false;
			while ( $charPos < $totalChars ) {
				$char = $chars[ $charPos ];
				if ( $char == '(' ) {
					// Открыта скобка - возможно, вызов ф-ции
					if ( $bracketLevel == 0 ) {
						$bracketsStart = $charPos;
					}
					$bracketLevel++;
				} else if ( $char == ')' ) {
					// Закрыта скобка - возможно, конец вызова ф-ции
					$bracketLevel--;
					if ( $bracketLevel == 0 ) {
						// Корневая ф-ция, вырезаем все, что между скобками, и парсим как аргументы
						if ( trim( $buffer ) == "" ) {
							// Функция без названия (скорее всего, условие в скобках)
						} else {
							// Функция с названием
							$rootCalledFunctions[] = array(
								'type' => 'function',
								'name' => trim( $buffer ),
								'offset' => $bracketsStart - mb_strlen( $buffer ), // начало функции
								'bracketsStartOffset' => $bracketsStart,	// onelineNostringBracketsStart
								'bracketsEndOffset' => $charPos,		// onelineNostringBracketsEnd
								'args' => self::parseNostringFunctionArgs( $scriptPath, mb_substr( $onelineNostring, $bracketsStart + 1, $charPos - $bracketsStart - 1 ) ),
								'argsString' => mb_substr( $onelineNostring, $bracketsStart + 1, $charPos - $bracketsStart - 1 ),
							);
						}
						$buffer = '';
					}
				} else {
					if ( $bracketLevel == 0 ) {
						// Не внутри скобок
						// Записываем в буфер, только если это - название функции
						if ( $char == ' ' || $char == "\t" ) {
							// Пробел или TAB
							$buffer .= $char;
							$lastWasSpace = true;
						} else if ( preg_match( '/[a-zA-Z0-9\_]/u', $char ) ) {
							// a-Z0-9_ - название функции (между символами которого пробел не допускается)
							if ( $lastWasSpace ) {
								// Был пробел - сбрасываем буффер
								$buffer = '';
							}
							$buffer .= $char;
							
							$lastWasSpace = false;
						} else if ( preg_match( '/[a-zA-Z0-9\_\.\:\[\]]/u', $char ) ) {
							// .:[] - возможно, части функции (разрешены в окружении пробелов)
							$buffer .= $char;
							
							$lastWasSpace = false;
						} else {
							// -=;{}, - символы, которые не используются в названии функций
							$buffer = '';
						}
					}
				}
				$charPos++;
			}
			
			// Рекурсивно собираем информацию о всех вызванных функциях
			$calledFunctions = self::_getCalledFunctionsFromRootRecurent( $scriptPath, $rootCalledFunctions );
			self::$_scriptsParsedData[ $scriptPath ][ 'calledFunctions' ] = $calledFunctions;
			
			// Ищем вызовы addEvent, чтобы узнать, какие события были добавлены моудем
			$moduleEvents = array();
			foreach ( $calledFunctions as $calledFunctionIndex => $functionData ) {
				if ( $functionData[ 'name' ] != 'addEvent' ) continue;
				
				if ( $functionData[ 'args' ][ 0 ][ 'type' ] != "string" ) {
					self::addError( self::ERR_ADD_EVENT_WRONG_SYNTAX, $scriptPath, $functionData[ 'lineIndex' ], 'Первый аргумент должен быть string, найдено: ' . $functionData[ 'args' ][ 0 ][ 'type' ] );
					continue;
				}
				
				if ( !isset( $functionData[ 'args' ][ 1 ] ) || $functionData[ 'args' ][ 1 ][ 'type' ] != "bool" ) {
					self::addError( self::ERR_ADD_EVENT_WRONG_SYNTAX, $scriptPath, $functionData[ 'lineIndex' ], 'Второй аргумент должен быть bool, найдено: ' . ( isset( $functionData[ 'args' ][ 1 ] ) ? $functionData[ 'args' ][ 1 ][ 'type' ] : 'ничего' ) );
					continue;
				}
				
				$eventName = $functionData[ 'args' ][ 0 ][ 'value' ][ 'string' ];
				$moduleEvents[ $eventName ] = array(
					'remoteTrigger' => $functionData[ 'args' ][ 1 ][ 'value' ],
					'calledFunctionIndex' => $calledFunctionIndex
				);
				
				// Проверяем название события (должно быть Module.on*)
				$sectionName = self::$_scriptsParsedData[ $scriptPath ][ 'lines' ][ $functionData[ 'lineIndex' ] ][ 'section' ];
				if ( $sectionName != "Внутренние события" && mb_substr( $eventName, 0, mb_strlen( self::$_scriptsParsedData[ $scriptPath ][ 'moduleNameCamel' ] ) + 3 ) != self::$_scriptsParsedData[ $scriptPath ][ 'moduleNameCamel' ] . '.on' ) {
					self::addError( self::ERR_WRONG_ADD_EVENT_NAME, $scriptPath, $functionData[ 'lineIndex' ], 'Название созданного события должно иметь вид "' . self::$_scriptsParsedData[ $scriptPath ][ 'moduleNameCamel' ]. '.on*", найдено: "' . $eventName . '"' );
				}
			}
			
			// Проверяем, есть ли описание добавленных событий, и принадлежат ли они к необходимым секциям
			foreach ( $moduleEvents as $eventName => $eventData ) {
				$syntax = false;
				$description = '';
				
				$lineIndex = self::$_scriptsParsedData[ $scriptPath ][ 'calledFunctions' ][ $eventData[ 'calledFunctionIndex' ] ][ 'lineIndex' ];
				
				// Проверяем комментарий
				if ( array_key_exists( $lineIndex, self::$_scriptsParsedData[ $scriptPath ][ 'comments' ] ) ) {
					// Есть комментарий к событию
					$eventComment = self::$_scriptsParsedData[ $scriptPath ][ 'comments' ][ $lineIndex ];
					$eventComment = trim( ltrim( $eventComment, '--' ) );
					
					$bracketsStart = -1;
					$bracketsEnd = -1;
					
					$chars = self::getStringChars( $eventComment );
					foreach ( $chars as $charPtr => $char ) {
						if ( $bracketsStart == -1 ) {
							// Еще не находили круглых скобок с аргументами
							if ( $char == '(' ) {
								// Начало аргументов
								$bracketsStart = $charPtr;
							} else {
								// Все еще описание
								$description .= $char;
							}
						} else {
							// Уже находили круглые скобки с аргументами
							if ( $bracketsEnd == -1 ) {
								// Еще не находили конца круглых скобок (находимся между скобок)
								if ( $char == ')' ) {
									// Конец списка аргументов
									$bracketsEnd = $charPtr;
									
									if ( $syntax === false ) $syntax = '';
								} else {
									// Все еще аргументы
									if ( $syntax === false ) $syntax = '';
									
									$syntax .= $char;
								}
							} else {
								// Уже находили конец круглых скобок
								$description .= $char;
							}
						}
					}
					
					$description = trim( $description );
					if ( $description == '' ) {
						self::addError( self::ERR_WRONG_ADD_EVENT_DESCRIPTION, $scriptPath, $lineIndex, "Отсутствует описание события. Строка должна иметь вид: addEvent( ... ) -- ( Синтаксис ) Описание события" );
					}
					if ( $syntax === false ) {
						self::addError( self::ERR_WRONG_ADD_EVENT_DESCRIPTION, $scriptPath, $lineIndex, "Отсутствует синтаксис события. Строка должна иметь вид: addEvent( ... ) -- ( Синтаксис ) Описание события" );
					} else {
						$syntax = trim( $syntax );
					}
				} else {
					// Комментария к событию нет
					self::addError( self::ERR_WRONG_ADD_EVENT_DESCRIPTION, $scriptPath, $lineIndex, "Отсутствует описание и синтаксис события. Строка должна иметь вид: addEvent( ... ) -- ( Синтаксис ) Описание события" );
				}
				
				$moduleEvents[ $eventName ][ 'syntax' ] = $syntax;
				$moduleEvents[ $eventName ][ 'description' ] = $description;
				
				// Проверяем секцию
				$sectionName = self::$_scriptsParsedData[ $scriptPath ][ 'lines' ][ $lineIndex ][ 'section' ];
				if ( $sectionName != 'Общие события' && $sectionName != 'Внутренние события' ) {
					// Неправильно указана секция
					self::addError( self::ERR_WRONG_ADD_EVENT_SECTION, $scriptPath, $lineIndex, "Неверно указана секция создаваемого события (--<[ Название секции ]>). Необходимо: \"Внутренние события\" или \"Внешние события\", найдено: \"" . $sectionName . "\""  );
				}
			}
			self::$_scriptsParsedData[ $scriptPath ][ 'moduleEvents' ] = $moduleEvents;
			
			// Ищем события, которые обрабатывает модуль
			$handledEvents = array();
			foreach ( self::$_scriptsParsedData[ $scriptPath ][ 'calledFunctions' ] as $calledFunctionIndex => $calledFunction ) {
				if ( $calledFunction[ 'name' ] == 'addEventHandler' ) {
					// addEventHandler
					if ( $calledFunction[ 'args' ][ 0 ][ 'type' ] == 'string' ) {
						// Название события задано строкой
						$handledEvents[] = array(
							'name' => $calledFunction[ 'args' ][ 0 ][ 'value' ][ 'string' ],
							'lineIndex' => $calledFunction[ 'lineIndex' ],
						);
					}
				}
			}
			self::$_scriptsParsedData[ $scriptPath ][ 'handledEvents' ] = $handledEvents;
			
			// Ищем уровни вложения таблиц для каждой вызванной функции
			$tableLevel = 0;
			$onelineNostringChars = self::getStringChars( self::$_scriptsParsedData[ $scriptPath ][ 'onelineNostring' ] );
			foreach ( $onelineNostringChars as $charIndex => $char ) {
				if ( $char == '{' ) {
					$tableLevel++;
				} else if ( $char == '}' ) {
					$tableLevel--;
				} else {
					foreach ( self::$_scriptsParsedData[ $scriptPath ][ 'calledFunctions' ] as $calledFunctionIndex => $calledFunctionData ) {
						if ( $calledFunctionData[ 'onelineOffset' ] == $charIndex ) {
							self::$_scriptsParsedData[ $scriptPath ][ 'calledFunctions' ][ $calledFunctionIndex ][ 'tableLevel' ] = $tableLevel;
							break;
						}
					}
				}
			}
			
			// Ищем ключевые слова начала блоков (do, for, function, if)
			$keywords = self::getBlockKeywords( self::$_scriptsParsedData[ $scriptPath ][ 'onelineNostring' ] );
			/*
			foreach ( $keywords as $onelineOffset => $kw ) {
				$lineInfo = self::onestringGetLineInfo( $onelineOffset, self::$_scriptsParsedData[ $scriptPath ][ 'onelineNostring' ], self::$_scriptsParsedData[ $scriptPath ][ 'onelineNostringMap' ] );
				self::log( ( $lineInfo[ 'lineIndex' ] + 1 ). ' ' . $kw );
			}
			
			die();
			*/
			
			// Ищем уровни вложений функций в блоки
			foreach ( self::$_scriptsParsedData[ $scriptPath ][ 'calledFunctions' ] as $calledFunctionIndex => $calledFunctionData ) {
				self::$_scriptsParsedData[ $scriptPath ][ 'calledFunctions' ][ $calledFunctionIndex ][ 'blocks' ] = array();
				
				$blockOffsets = array(); // [] keywordOnelineOffset
				foreach ( $keywords as $kwOnelineOffset => $kwName ) {
					if ( $calledFunctionData[ 'onelineOffset' ] <= $kwOnelineOffset ) {
						// Функция начинается раньше, чем начинается это ключевое слово (ключевое слово не обрабатывается)
						$blocks = array();
						foreach ( $blockOffsets as $offset ) {
							$lineInfo = self::onestringGetLineInfo( $offset, self::$_scriptsParsedData[ $scriptPath ][ 'onelineNostring' ], self::$_scriptsParsedData[ $scriptPath ][ 'onelineNostringMap' ] );
							$blocks[ $offset ] = array(
								'name' => $keywords[ $offset ],
								'lineIndex' => $lineInfo[ 'lineIndex' ]
							);
						}
						ksort( $blocks );
						
						self::$_scriptsParsedData[ $scriptPath ][ 'calledFunctions' ][ $calledFunctionIndex ][ 'blocks' ] = $blocks;
						
						break;
					} else {
						// Функция начинается позже, чем начинается ключевое слово
						if ( $kwName == 'end' ) {
							array_pop( $blockOffsets );
						} else {
							array_push( $blockOffsets, $kwOnelineOffset );
						}
					}
				}
			}
			
			// Проверяем, всем ли функциям установлен уровень вложения
			foreach ( self::$_scriptsParsedData[ $scriptPath ][ 'calledFunctions' ] as $calledFunctionIndex => $calledFunctionData ) {
				if ( !isset( $calledFunctionData[ 'tableLevel' ] ) ) {
					self::addError( self::ERR_INSPECTOR_UNKNOWN_TABLE_LEVEL, $scriptPath, $calledFunctionData[ 'lineIndex' ], 'Неизвестный уровень вложения таблицы (функция "' . $calledFunctionData[ 'name' ] . '")' );
				}
			}
			
			// Ищем функции первого уровня вложения (функции модуля) и комментарии к ним
			$moduleFunctions = array();
			foreach ( self::$_scriptsParsedData[ $scriptPath ][ 'calledFunctions' ] as $calledFunctionIndex => $calledFunctionData ) {
				if ( $calledFunctionData[ 'rootCall' ] ) {
					if ( $calledFunctionData[ 'tableLevel' ] == 1 ) {
						if ( $calledFunctionData[ 'name' ] == 'function' ) {
							if ( sizeof( $calledFunctionData[ 'blocks' ] ) == 0 ) {
								// Парсим строку, чтобы получить название функции
								$functionDeclarationLine = self::$_scriptsParsedData[ $scriptPath ][ 'lines' ][ $calledFunctionData[ 'lineIndex' ] ][ 'source' ];
								if ( preg_match( '/([a-zA-Z0-9\_]+)[\s]*\=[\s]*function/', $functionDeclarationLine, $matches ) ) {
									$functionName = $matches[1];
									
									// Получаем синтаксис функции
									$args = array();
									foreach ( $calledFunctionData[ 'args' ] as $arg ) {
										if ( $arg[ 'type' ] != 'misc' ) {
											// Не misc?
											self::addError( self::ERR_WRONG_MODULE_FUNCTION_SYNTAX, $scriptPath, $calledFunctionData[ 'lineIndex' ], "Неправильно заданы аргументы функции модуля" );
										}
										$args[] = $arg[ 'value' ];
									}
									
									$moduleFunctions[ $functionName ] = array(
										'args' => $args,
										'lineIndex' => $calledFunctionData[ 'lineIndex' ]
									);
									
									// Описание из комментариев
									$description = array(
										'brief' => array(),
										'args' => array(),
										'return' => false
									);
									if ( $functionName != 'init' && !(
										mb_substr( $functionName, 0, 1 ) == '_'
										|| (
											mb_substr( $functionName, 0, 2 ) == 'on' 
											&& strtoupper( mb_substr( $functionName, 2, 1 ) ) == mb_substr( $functionName, 2, 1 )
										)
									) ) {
										// Общая функция - ищем описание функции в комментариях перед ней
										for ( $lineIndex = $calledFunctionData[ 'lineIndex' ] - 1; $lineIndex >= 0; $lineIndex-- ) {
											if ( !array_key_exists( $lineIndex, self::$_scriptsParsedData[ $scriptPath ][ 'comments' ] ) ) {
												// Не комментарий
												break;
											} else {
												// Комментарий
												$comment = self::$_scriptsParsedData[ $scriptPath ][ 'comments' ][ $lineIndex ];
												$commentType = mb_substr( trim( $comment ), 0, 4 );
												
												if ( $commentType == '-- >' ) {
													// Аргумент функции
													$comment = trim( mb_substr( $comment, 4 ) );
													$argumentData = array(
														'dataTypes' => array(),
														'name' => '',
														'description' => '',
													);
													
													$hyphenExpl = explode( '-', $comment );
													$nameAndDataTypes = trim( $hyphenExpl[ 0 ] );
													array_shift( $hyphenExpl );
													
													if ( sizeof( $hyphenExpl ) != 0 ) {
														$argumentData[ 'description' ] = trim( implode( '-', $hyphenExpl ) );
													}
													
													$spaceExpl = explode( ' ', $nameAndDataTypes );
													$argumentData[ 'name' ] = $spaceExpl[0];
													array_shift( $spaceExpl );
													
													if ( sizeof( $spaceExpl ) != 0 ) {
														$dataTypesString = trim( implode( '', $spaceExpl ) );
														$argumentData[ 'dataTypes' ] = explode( '/', $dataTypesString );
													} else {
														self::addError( self::ERR_NO_FUNCTION_ARG_DATATYPE_DESCRIPTION, $scriptPath, $calledFunctionData[ 'lineIndex' ], "Отсутствует определение допустимых типов данных аргумента функции (строка должна иметь вид \"-- > argName table/string/nil - описание аргумента\")" );
													}
													
													$description[ 'args' ][] = $argumentData;
												} else if ( $commentType == '-- =' ) {
													// Что возвращает функция
													// table / nil addStatus, string / nil errorMessage
													// void
													$comment = trim( mb_substr( $comment, 4 ) );
													$returnItems = array();
													
													if ( $comment == 'void' ) {
														// Не возвращает ничего
														$returnItems = null;
													} else {
														// Что-то возвращает
														$commaExpl = explode( ',', $comment );
														foreach ( $commaExpl as $returnedElementStr ) {
															// table / nil addStatus
															$returnedElementStr = trim( $returnedElementStr );
															
															$slashExpl = explode( '/', $returnedElementStr );	// [ table ], [ nil addStatus ]
															$itemNameArg = $slashExpl[ sizeof( $slashExpl ) - 1 ];	// [ nil addStatus ]
															$itemNameArgExpl = explode( ' ', $itemNameArg );	// [ nil ], [ addStatus ]
															$itemName = array_pop( $itemNameArgExpl );	// addStatus
															$slashExpl[ sizeof( $slashExpl ) - 1 ] = implode( ' ', $itemNameArgExpl );	// $slashExpl = [ table ], [ nil ]
															foreach ( $slashExpl as $k => $v ) {
																$slashExpl[ $k ] = trim( $v );
															}
															
															$returnItems[] = array(
																'dataTypes' => $slashExpl,
																'name' => $itemName,
															);
														}
													}
													
													$description[ 'return' ] = $returnItems;
												} else {
													// Описание функции
													$comment = trim( ltrim( $comment, "-" ) );
													$description[ 'brief' ][] = $comment;
												}
											}
										}
										
										if ( sizeof( $description[ 'brief' ] ) == 0 ) {
											// Нет описания функции
											self::addError( self::ERR_NO_FUNCTION_BRIEF_DESCRIPTION, $scriptPath, $calledFunctionData[ 'lineIndex' ], "Отсутствует общее описание функции (комментарий перед функцией)" );
										}
										
										if ( $description[ 'return' ] === false ) {
											// Нет описания возвращаемого значения
											self::addError( self::ERR_NO_FUNCTION_RETURN_DESCRIPTION, $scriptPath, $calledFunctionData[ 'lineIndex' ], "Отсутствует описание возвращаемых значений функции (-- =)" );
										}
										
										if ( sizeof( $description[ 'args' ] ) < sizeof( $args ) ) {
											// Отсутствует описание для некоторых аргументов
											self::addError( self::ERR_NO_FUNCTION_ARGS_DESCRIPTION, $scriptPath, $calledFunctionData[ 'lineIndex' ], "Отсутствует описание к некоторым агрументам функции (-- >)" );
										}
									}
									$description[ 'args' ] = array_reverse( $description[ 'args' ] ); // Ведь мы шли снизу вверх
									
									// Проверим порядок документации аргументов
									if ( sizeof( $moduleFunctions[ $functionName ][ 'args' ] ) != 0 && $moduleFunctions[ $functionName ][ 'args' ][ 0 ] != '...' ) {
										// Функция, в которой аргументы заданы не как ...
										foreach ( $description[ 'args' ] as $idx => $arg ) {
											if ( !array_key_exists( $idx, $moduleFunctions[ $functionName ][ 'args' ] ) ) {
												// Описание к аргументу, которого нет
												self::addError( self::ERR_EXCESSIVE_ARG_DESCRIPTION, $scriptPath, $calledFunctionData[ 'lineIndex' ], "Количество описаний аргументов превышает количество действительных аргументов функции" );
											} else if ( $moduleFunctions[ $functionName ][ 'args' ][ $idx ] != $arg[ 'name' ] ) {
												// Название аргумента в описании не соответствует аргументу в функции
												self::addError( self::ERR_WRONG_ARG_NAME_IN_DESCRIPTION, $scriptPath, $calledFunctionData[ 'lineIndex' ], "Порядок аргументов в описании функции не соответствует порядку действительных аргументов функции (на месте " . $arg[ 'name' ] . " ожидается " . $moduleFunctions[ $functionName ][ 'args' ][ $idx ] . " )" );
											}
										}
									}
									
									$moduleFunctions[ $functionName ][ 'description' ] = $description;
								} else {
									// Неправильный формат
									self::addError( self::ERR_WRONG_MODULE_FUNCTION_DECLARATION, $scriptPath, $calledFunctionData[ 'lineIndex' ], "Неправильно задана функция модуля. Строка ложна иметь вид: \"someFunction = function( ... )\"" );
								}
							}
						}
					}
				}
			}
			self::$_scriptsParsedData[ $scriptPath ][ 'moduleFunctions' ] = $moduleFunctions;
			
			// Запись кэша
			$hash = substr( md5( file_get_contents( self::ROOT . $scriptPath ) ), 0, 8 );
			self::$_scriptsParsedData[ $scriptPath ][ 'cacheHash' ] = $hash;
			
			file_put_contents( self::ROOT . 'inspector/cache/' . $hash . '.json', json_encode( self::$_scriptsParsedData[ $scriptPath ], JSON_UNESCAPED_UNICODE ) );
			
			return self::$_scriptsParsedData[ $scriptPath ];
		}
		
		// Внутреннее использование - собирает все функции из $rootCalledFunctions и ищет их lineIndex
		private static function _getCalledFunctionsFromRootRecurent( $scriptPath, $args, $offset = 0 ) {
			$functions = array();
			foreach ( $args as $arg ) {
				if ( $arg[ 'type' ] == 'function' ) {
					$functionOffset = $offset + $arg[ 'offset' ];
					$lineIndex = self::onestringGetLineIndex( $functionOffset, self::$_scriptsParsedData[ $scriptPath ][ 'onelineNostring' ], self::$_scriptsParsedData[ $scriptPath ][ 'onelineNostringMap' ] );
					
					$functionInfo = array(
						'name' => $arg[ 'name' ],
						'onelineOffset' => $functionOffset,
						'lineIndex' => $lineIndex,
						'rootCall' => $offset == 0,
						'args' => $arg[ 'args' ],
					);
					$functions[] = $functionInfo;
					
					$functions = array_merge( $functions, self::_getCalledFunctionsFromRootRecurent( $scriptPath, $arg[ 'args' ], $offset + $arg[ 'bracketsStartOffset' ] + 1 ) );
				} else if ( $arg[ 'type' ] == 'anonymous function' ) {
					// Вырезанная ранее анонимная функция внутри ()
					// Ищем вызовы других функций в ней
					
					// Ищем вызываемые функции
					$chars = self::getStringChars( $arg[ 'value' ] );
					$totalChars = sizeof( $chars );
					$charPos = mb_strpos( $arg[ 'value' ], ')' ) + 1;
					$buffer = '';
					$bracketLevel = 0;
					$bracketsStart = -1;
					$rootCalledFunctions = array();
					$lastWasSpace = false;
					while ( $charPos < $totalChars ) {
						$char = $chars[ $charPos ];
						if ( $char == '(' ) {
							// Открыта скобка - возможно, вызов ф-ции
							if ( $bracketLevel == 0 ) {
								$bracketsStart = $charPos;
							}
							$bracketLevel++;
						} else if ( $char == ')' ) {
							// Закрыта скобка - возможно, конец вызова ф-ции
							$bracketLevel--;
							if ( $bracketLevel == 0 ) {
								// Корневая ф-ция, вырезаем все, что между скобками, и парсим как аргументы
								if ( trim( $buffer ) == "" ) {
									// Функция без названия (скорее всего, условие в скобках)
								} else {
									// Функция с названием
									$rootCalledFunctions[] = array(
										'type' => 'function',
										'name' => trim( $buffer ),
										'offset' => $bracketsStart - mb_strlen( $buffer ), // начало функции
										'bracketsStartOffset' => $bracketsStart,	// onelineNostringBracketsStart
										'bracketsEndOffset' => $charPos,		// onelineNostringBracketsEnd
										'args' => self::parseNostringFunctionArgs( $scriptPath, mb_substr( $arg[ 'value' ], $bracketsStart + 1, $charPos - $bracketsStart - 1 ) ),
										'argsString' => mb_substr( $arg[ 'value' ], $bracketsStart + 1, $charPos - $bracketsStart - 1 ),
									);
								}
								$buffer = '';
							}
						} else {
							if ( $bracketLevel == 0 ) {
								// Не внутри скобок
								// Записываем в буфер, только если это - название функции
								if ( $char == ' ' || $char == "\t" ) {
									// Пробел или TAB
									$buffer .= $char;
									$lastWasSpace = true;
								} else if ( preg_match( '/[a-zA-Z0-9\_]/u', $char ) ) {
									// a-Z0-9_ - название функции (между символами которого пробел не допускается)
									if ( $lastWasSpace ) {
										// Был пробел - сбрасываем буффер
										$buffer = '';
									}
									$buffer .= $char;
									
									$lastWasSpace = false;
								} else if ( preg_match( '/[a-zA-Z0-9\_\.\:\[\]]/u', $char ) ) {
									// .:[] - возможно, части функции (разрешены в окружении пробелов)
									$buffer .= $char;
									
									$lastWasSpace = false;
								} else {
									// -=;{}, - символы, которые не используются в названии функций
									$buffer = '';
								}
							}
						}
						$charPos++;
					}
					//self::log( $rootCalledFunctions );
					
					$functions = array_merge( $functions, self::_getCalledFunctionsFromRootRecurent( $scriptPath, $rootCalledFunctions, $offset + $arg[ 'offset' ] ) );
				}
			}
			
			return $functions;
		}
		
		private static function getBlockKeywords( $oneline ) {
			$onelineNostringChars = self::getStringChars( $oneline );
			
			$blockTypes = array( 'do', 'function', 'if', 'end' ); // 'for' выпилен, так как там есть do
			$keywords = array();
			
			foreach ( $blockTypes as $blockType ) {
				$charPtr = 0;
				$blockStart = mb_strpos( $oneline, $blockType, $charPtr );
				
				//self::log( $blockType );
				while ( $blockStart !== false )  {
					// Найдено слово - проверяем, может ли оно быть ключевым
					$canBeKeyword = true;
					
					$charBeforePos = $blockStart - 1;
					if ( $blockStart != 0 ) {
						$charBefore = $onelineNostringChars[ $charBeforePos ];
						if ( !in_array( $charBefore, array( ' ', "\t", ')', '(', '{', '}', ';', ',' ) ) ) {	// Допустимые символы перед ключевым словом
							$canBeKeyword = false;
							//self::log( "Char before: " . $charBefore . ' (' . ( $charBeforePos ) . ')' );
						}
					}
					$charAfterPos = $blockStart + mb_strlen( $blockType );
					if ( $canBeKeyword && $charAfterPos != sizeof( $onelineNostringChars ) ) {
						$charAfter = $onelineNostringChars[ $charAfterPos ];
						if ( !in_array( $charAfter, array( ' ', "\t", ')', '(', '{', '}', ';', ',' ) ) ) {	// Допустимые символы после ключевого слова
							$canBeKeyword = false;
							//self::log( "Char after: " . $charAfter . ' (' . ( $charAfterPos ) . ')' );
						}
					}
					
					if ( $canBeKeyword ) {
						//self::log( 'KW:' . $charPtr . ' ' . $blockStart . ' ' . $blockType );
						$keywords[ $blockStart ] = $blockType;
					} else {
						//self::log( 'Not KW:' . $charPtr . ' ' . $blockStart . ' ' . $blockType );
					}
					$charPtr = $blockStart + mb_strlen( $blockType );
					
					$blockStart = mb_strpos( $oneline, $blockType, $charPtr );
				}
			}
			
			ksort( $keywords );
			
			return $keywords;
		}
		
		private static function parseNostringFunctionArgs( $scriptPath, $str ) {
			// Возвращает массив аргументов функции, рекурсивно
			// Принимает строку, которая содержит все между ( и ) вызываемой функции
			// ( function( abc ) ... end, def( 123, ghi ), jkl() < 1 + a )
			
			$chars = self::getStringChars( $str );
			$totalChars = sizeof( $chars );
			
			// Разрезаем строку по запятой, в местах, где bracketLevel == 0
			$args = array();
			$arg = '';
			$charPos = 0;
			
			while ( $charPos < $totalChars ) {
				$char = $chars[ $charPos ];
				//self::log( 'C: ' . $char );
				if ( $char == '(' ) {
					// Открыта скобка - ищем парную закрывающую скобку, и все, что между ними, передаем рекурсивно
					if ( trim( $arg ) == 'function' ) {
						// Это "function (..." - анонимная функция, которую надо выреать
						// function ( abc, def ) if ( abc > 1 ) then def = 2 end; end, abc, 123
						
						// Находим позиции ключевых слов
						$anonymousFunctionStart = $charPos;	// Позиция скобки (в $keywords не будет первого блока function)
						$keywords = self::getBlockKeywords( mb_substr( $str, $anonymousFunctionStart ) );
						
						// Ищем, где закрывается самый первый блок
						$blockLevel = 0;
						foreach ( $keywords as $kwOffset => $kwName ) {
							if ( $kwName == 'end' ) {
								$blockLevel--;
								if ( $blockLevel == -1 ) {
									// Нашли конец анонимной функции
									$args[] = array(
										'type' => 'anonymous function',
										'value' => mb_substr( $str, $anonymousFunctionStart, $kwOffset ),
										'offset' => $anonymousFunctionStart,
									);
									
									$charPos += $kwOffset;
									break;
								}
							} else {
								$blockLevel++;
							}
						}
					} else {
						// Что-то другое
						$bracketLevel = 0;
						$i = $charPos + 1;
						while ( $i < $totalChars ) {
							$c = $chars[ $i ];
							//self::log( 'SC: ' . $c );
							if ( $c == '(' ) {
								$bracketLevel++;
								//self::log( "Bracket level +: " . $bracketLevel );
							} else if ( $c == ')' ) {
								$bracketLevel--;
								//self::log( "Bracket level -: " . $bracketLevel );
								if ( $bracketLevel == -1 ) {
									// Нашли закрывающую скобку
									$argsString = mb_substr( $str, $charPos + 1, $i - $charPos - 1 );
									$argInfo = array(
										'args' => self::parseNostringFunctionArgs( $scriptPath, $argsString ),
										'argsString' => $argsString,
										'offset' => $charPos - mb_strlen( ltrim( $arg ) ),
										'bracketsStartOffset' => $charPos,
										'bracketsEndOffset' => $i,
									);
									if ( trim( $arg ) != '' ) {
										// Перед закрывающей скобкой что-то было - обрезаем название функции (с конца)
										$argInfo[ 'type' ] = 'function';
										$argInfo[ 'src' ] = $arg;
										
										$notHandledName = ltrim( $arg );
										
										$name = '';
										$nameChars = self::getStringChars( trim( $arg ) );
										$wasSpace = false;
										$wasDot = false;
										$wasNormal = false;
										$wasNormalBefore = false;
										for ( $j = sizeof( $nameChars ) - 1; $j >= 0; $j-- ) {
											$nameChar = $nameChars[ $j ];
											if ( $nameChar == "\t" || $nameChar == ' ' ) {
												$wasNormalBefore = $wasNormal;
												$wasSpace = true;
												$wasNormal = false;
												$wasDot = false;
											} else if ( $nameChar == '.' ) {
												if ( $wasDot ) {
													// Две точки подряд
													//self::log( 'Two dots' );
													break;
												}
												$wasDot = true;
												$wasNormalBefore = $wasNormal;
												$wasNormal = false;
												$wasSpace = false;
												$name = '.' . $name;
											} else if ( preg_match( '/[a-zA-Z0-9\_]/u', $nameChar ) ) {
												// Разрешено в названии функций
												if ( $wasSpace && $wasNormalBefore ) {
													// Между символами пробел - так нельзя
													//self::log( 'Space between characters' );
													break;
												}
												$name = $nameChar . $name;
												$wasNormalBefore = $wasNormal;
												$wasDot = false;
												$wasNormal = true;
												$wasSpace = false;
											} else {
												// Не разрешено в названии функций
												break;
											}
										}
										
										$name = ltrim( $name, '.' );
										
										if ( $name == '' ) {
											// Пустая строка (не функция вовсе, может, скобки использованы при конкатенации строки )
											$argInfo = false;
										} else {
											//self::log( $name . ' ' . trim( $arg ) );
											$argInfo[ 'name' ] = $name;
											$argInfo[ 'offset' ] += ( mb_strlen( $notHandledName ) - mb_strlen( $name ) );
										}
										
										$arg = '';
									} else {
										$argInfo[ 'type' ] = 'brackets';
									}
									if ( $argInfo != false ) {
										$args[] = $argInfo;
									}
									$charPos = $i;
									break;
								}
							}
							$i++;
						}
					}
				} else if ( $charPos + 1 == $totalChars || $char == ',' ) {
					// Конец строки или запятая - конец аргумента
					if ( trim( $arg ) == '' ) {
						// Пустой аргумент?
						//$args[] = array(
						//	'type' => 'empty'
						//);
					} else {
						// Аргумент (строка / число, прочее)
						$src = $arg;
						if ( is_numeric( trim( $arg ) ) ) {
							$type = 'number';
							$value = trim( $arg );
						} else if ( array_key_exists( mb_substr( trim( $arg ), 3 ), self::$_scriptsParsedData[ $scriptPath ][ 'strings' ] ) ) {
							$type = 'string';
							$value = array(
								'index' => mb_substr( trim( $arg ), 3 ),
								'string' => self::$_scriptsParsedData[ $scriptPath ][ 'strings' ][ mb_substr( trim( $arg ), 3 ) ][ 'string' ],
							);
						} else if ( trim( $arg ) == 'false' ) {
							$type = 'bool';
							$value = false;
						} else if ( trim( $arg ) == 'true' ) {
							$type = 'bool';
							$value = true;
						} else if ( trim( $arg ) == 'nil' ) {
							$type = 'nil';
							$value = null;
						} else {
							$type = 'misc';
							$value = trim( $arg );
						}
						$args[] = array(
							'type' => $type,
							'value' => $value,
							'src' => $src,
							'offset' => $charPos - mb_strlen( $arg ),	// Смещение от начала скобок (с учетом пробелов) для строки src
						);
					}
					$arg = '';
				} else {
					// Что-то еще - считаем данными аргумента
					$arg .= $char;
				}
				
				$charPos++;
			}
			
			if ( $arg != '' ) {
				$args[] = trim( $arg );
			}
			
			return $args;
		}
		
		private static function onestringGetLineIndex( $characterPos, &$oneline, &$map ) {
			$sizeAccumulator = 0;
			$found = false;
			
			foreach ( $map as $lineIndex => $lineSize ) {
				if ( $characterPos < $sizeAccumulator + $lineSize ) {
					return $lineIndex;
				}
				$sizeAccumulator += $lineSize;
			}
			
			// Такого смещения нет или последняя строка
			return false;
		}
		
		private static function onestringGetLineInfo( $characterPos, &$oneline, &$map ) {
			$sizeAccumulator = 0;
			$found = false;
			
			foreach ( $map as $lineIndex => $lineSize ) {
				if ( $characterPos < $sizeAccumulator + $lineSize ) {
					return array(
						'lineIndex' => $lineIndex,
						'length' => $lineSize,
						'startPos' => $sizeAccumulator //mb_substr( $oneline, $sizeAccumulator, $lineSize );	// Не забываем, что в oneline в конце каждой строки есть пробел
					);
					break;
				}
				$sizeAccumulator += $lineSize;
			}
			
			// Такого смещения нет или последняя строка
			return false;
		}
		
		private static function onestringGetLine( $characterPos, &$oneline, &$map ) {
			$info = self::onestringGetLineInfo( $characterPos, $oneline, $map );
			
			if ( $info == false ) {
				return false;
			} else {
				return mb_substr( $oneline, $info[ 'startPos' ], $info[ 'length' ] );
			}
		}
		
		// Возвращает строку без lua-строк, учитывает строки с переносом (\ в конце строки)
		private static function lineWithoutStrings( $filePath, $lineIndex, $str ) {
			if ( array_key_exists( $filePath, self::$_escapedNewLines ) && array_key_exists( $lineIndex, self::$_escapedNewLines[ $filePath ] ) ) {
				// Эта строка начинается среди lua-строки, идем к концу строки, пока не уткнемся в кавычки
				$openedQuote = self::$_escapedNewLines[ $filePath ][ $lineIndex ];
				$chars = self::getStringChars( $str );
				
				$foundStringEnd = false;
				$escaped = false;
				for ( $i = 0; $i < sizeof( $chars ); $i++ ) {
					if ( $escaped ) {
						$escaped = false;
					} else {
						if ( $chars[ $i ] == "\\" ) {
							$escaped = true;
						} else {
							// Неэкранированный символ
							if ( $chars[ $i ] == $openedQuote ) {
								// Нашли окончание строки
								$foundStringEnd = true;
								$str = mb_substr( $str, $i + 1 );
								break;
							}
						}
					}
				}
				
				if ( !$foundStringEnd || trim( $str ) == '' ) {
					// Полностью строка
					return $openedQuote == "'" ? '_sqs_' : '_dqs_';
				}
			}
			
			// Вырезаем строки
			$chars = self::getStringChars( $str );
			$inSingleQuote = false;
			$inDoubleQuote = false;
			$escaped = false;
			$nostring = '';
			for ( $i = 0; $i < sizeof( $chars ); $i++ ) {
				if ( $chars[ $i ] == "\\" ) {
					$escaped = true;
				} else {
					// Неэкранированный символ
					if ( $inSingleQuote ) {
						// Внутри ''
						if ( $chars[ $i ] == "'" ) {
							// Конец ''
							$inSingleQuote = false;
						}
					} else {
						// Не внутри ''
						if ( $inDoubleQuote ) {
							// Внутри ""
							if ( $chars[ $i ] == '"' ) {
								// Конец ""
								$inDoubleQuote = false;
							}
						} else {
							// Не внутри ""
							if ( $chars[ $i ] == '"' ) {
								// Начало строки ""
								$nostring .= "_dqs_";
								$inDoubleQuote = true;
							} else if ( $chars[ $i ] == "'" ) {
								// Начало строки ''
								$nostring .= "_sqs_";
								$inSingleQuote = true;
							} else {
								// Код Lua
								$nostring .= $chars[ $i ];
							}
						}
					}
				}
			}
			
			return $nostring;
		}
		
		// Возвращает true, если это строка вида "... function( a, b ... )"
		private static function isFunctionDeclarationString( $line ) {
			if ( mb_substr( $line, -1 ) != ')' ) {
				return false;
			} else {
				// Строка вида "...)"
				preg_match( '/function[\s]*\([^\)]*\)/', $line, $matches );
				return sizeof( $matches ) != 0;
			}
		}
		
		private static function getLineTabSize( $line ) {
			$chars = self::getStringChars( $line );
			
			$tabs = 0;
			$spaces = 0;
			
			foreach ( $chars as $char ) {
				if ( $char == "\t" ) {
					$tabs++;
				} else if ( $char == " " ) {
					$spaces++;
				} else {
					break;
				}
			}
			
			return $tabs + floor( $spaces / 4 );
		}
		
		private static function getStringChars( $str ) {
			return preg_split('/(?<!^)(?!$)/u', $str );
		}
		
		private static function getScriptList() {
			if ( self::$_scripts == null ) {
				$scriptList = array();
				$metaXml = file( self::ROOT . 'meta.src.xml' );
				foreach ( $metaXml as $metaLine ) {
					$metaLine = trim( $metaLine );
					if ( mb_substr( $metaLine, 0, 8 ) == "<script " ) {
						// Скрипт
						preg_match( '/src="([^\"]+)"/', $metaLine, $matches );
						$filePath = $matches[ 1 ];
						
						preg_match( '/type="([^\"]+)"/', $metaLine, $matches );
						$fileType = $matches[ 1 ];
						
						$scriptList[] = array(
							'path' => $filePath,
							'type' => $fileType,
						);
					}
				}
				
				self::$_scripts = $scriptList;
			}
			
			return self::$_scripts;
		}
		
		// Возвращает массив строк файла
		private static function getScriptContents( $scriptPath ) {
			if ( !array_key_exists( $scriptPath, self::$_scriptContents ) ) {
				if ( !file_exists( self::ROOT . $scriptPath ) ) {
					throw new Exception( 'Script file not found' );
				}
				
				$lines = file( self::ROOT . $scriptPath );
				
				self::$_scriptContents[ $scriptPath ] = $lines;
				
				// Ищем строки с \ в конце и кэшируем информацию о них (для lineWithoutStrings)
				foreach ( $lines as $lineIndex => $str ) {
					$str = rtrim( $str );
					if ( mb_substr( $str, -1 ) == "\\" ) {
						// Строка заканчивается на \ - отмечаем следующую строку и ищем, какую кавычку использовали
						
						if ( !array_key_exists( $scriptPath, self::$_escapedNewLines ) ) {
							self::$_escapedNewLines[ $scriptPath ] = array();
						}
						
						$backwrdLineIndex = $lineIndex;
						while ( $backwrdLineIndex != -1 ) {
							$qoute = self::findLastQuote( $scriptPath, $backwrdLineIndex );
							if ( $qoute ) {
								self::$_escapedNewLines[ $scriptPath ][ $lineIndex+1 ] = $qoute;
								break;
							} else {
								$backwrdLineIndex--;
							}
						}
					}
				}
				
			}
			
			return self::$_scriptContents[ $scriptPath ];
		}
		
		// Находит последнюю кавычку в строке (ищет с конца), учитывает экранирование
		private static function findLastQuote( $scriptPath, $lineIndex ) {
			// Идет с конца строки, пока не найдет ' или " без экранирования
			$s = self::$_scriptContents[ $scriptPath ][ $lineIndex ];
			
			$chars = self::getStringChars( $s );
			if ( sizeof( $chars ) != 0 ) {
				for ( $i = sizeof( $chars ) - 1; $i >= 0; $i-- ) {
					if ( $chars[ $i ] == '"' || $chars[ $i ] == "'" ) {
						// Кавычка, считаем кол-во бэкслешей перед ней
						$backslashCount = 0;
						for ( $j = $i - 1; $j >= 0; $j-- ) {
							if ( $chars[ $j ] == "\\" ) {
								$backslashCount++;
							} else {
								break;
							}
						}
						
						if ( $backslashCount % 2 == 0 ) {
							// Нет экранирования или парное число слэшей
							return $chars[ $i ];
						}
					}
				}
			}
			
			return false;
		}
		
		private static function toCamelCase( $str, $capitalizeFirstCharacter = true ) {
			$str = str_replace( ' ', '', ucwords( str_replace( '-', ' ', $str ) ) );

			if ( !$capitalizeFirstCharacter ) {
				$str[0] = strtolower( $str[0] );
			}

			return $str;
		}
		
		private static function camelToHyphen( $str ) {
			// AbcDef => abc-def
			return ltrim( strtolower( preg_replace( '/[A-Z]/', '-$0', $str) ), '-' );
		}
		
		// getModuleScriptPath( 'client', 'GUI' );
		// Возвращает путь к файлу модуля, который имеет тип $type (или shared) и модуль $name
		private static function getModuleScriptPath( $type, $name ) {
			foreach ( self::$_scriptsParsedData as $scriptPath => $scriptData ) {
				if ( ( $scriptData[ 'moduleNameCamel' ] == $name && $type == 'shared' ) || ( $scriptData[ 'moduleNameCamel' ] == $name && ( $scriptData[ 'moduleType' ] == $type || $scriptData[ 'moduleType' ] == 'shared' ) ) ) {
					return $scriptPath;
				}
			}
			
			return false;
		}
		
		// Узнать фактическую длину строки (без символов переноса строк и с учетом размера tab)
		private static function getFactStringLength( $str, $tabSize = 4 ) {
			$str = str_replace( array( "\r\n", "\n" ), '', $str );
						
			$lineFactLength = 0;
			$chars = self::getStringChars( $str );
			foreach ( $chars as $char ) {
				if ( $char == "\t" ) {
					$lineFactLength += $tabSize;
				} else {
					$lineFactLength++;
				}
			}
			
			return $lineFactLength;
		}
		
		private static function obfuscateSourceLine( $str ) {
			$chars = self::getStringChars( $str );
			$out = '';
			foreach ( $chars as $char ) {
				if ( preg_match( '/[a-zA-Zа-яА-ЯёЁїЇєЄіІ]+/', $char ) ) {
					if ( self::isVowel( $char ) ) {
						$nc = substr( str_shuffle( str_repeat( "aeiou", 1 ) ), 0, 1 );
					} else {
						$nc = substr( str_shuffle( str_repeat( "bcdfghklmnprstvwyz", 1 ) ), 0, 1 );
					}
					
					if ( mb_strtolower( $char ) != $char ) {
						$nc = mb_strtoupper( $nc );
					}
					$out .= $nc;
				} else if ( is_numeric( $char ) ) {
					$out .= rand(0,9);
				} else {
					$out .= $char;
				}
			}
			
			return $out;
		}
		
		// true, если буква гласная
		private static function isVowel( $c ) {
			$vowels = array( 'a', 'e', 'i', 'o', 'u', 'а', 'е', 'ё', 'и', 'о', 'у', 'э', 'я', 'ї', 'і' );
			$c = mb_strtolower( $c );
			
			return in_array( $c, $vowels );
		}
	}
	
	// Запускаем
	set_time_limit( 0 );
	mb_internal_encoding( "UTF-8" );
	
	Inspector::start();