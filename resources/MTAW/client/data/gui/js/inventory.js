"use strict";
var Inventory = {
	/*
		Возможные действия Inventory.:
		- grabDragging( slotType, slotID, count ) - Взять count вещей из слота в dragging
		- dropDragging( count ) - Выбросить dragging в количестве count
		- putDragging( slotType, slotID, count ) - Вставить dragging в слот в количестве count
		- dropSlot( slotType, slotID, count ) - Выбросить из слота count вещей
		- moveSlot( fromSlotType, fromSlotID, toSlotType, toSlotID, count ) - Переместить count вещей из одного слота в другой
	*/
	
	draggingItem : null,		// Вещь, которую тащит игрок. Вещь находится в отдельном слоту (не в инвентаре), поэтому обрабатываются только действия "конейнер -> dragging" и "dragging -> контейнер". Действий "контейнер -> контейнер" нет
	activeFastSlot : null,
	
	isActive : false,
	
	isHovered : false,
	
	init : function() {
		// Инициализация кругового прогресс-бара использования вещи
		$( "#inv-usage-progress-circle" ).knob({
			bgColor  : "rgba(0,0,0,0.5)",
			thickness  : 0.33,
			width : 32,
			displayInput : false,
			fgColor : "#4af"
		});
		
		// Обработчик hover и blur - чтобы можно было узнать, навел игрок мышку на инвентарь или нет
		$( '#inv' ).on( 'mouseenter mouseleave', function( e ) {
			if ( e.type == 'mouseenter' ) {
				Inventory.isHovered = true;
			} else {
				Inventory.isHovered = false;
			}
		} );
		
		// Обрабатываем клик за инвентарем
		var lastMousedown = 0;
		$( window ).on( 'mousedown', function( e ) {
			if ( e.timeStamp - lastMousedown > 40 ) {
				lastMousedown = e.timeStamp;
				
				if ( !Inventory.isHovered ) {
					var keyName = false;
				
					if ( event.which == 1 ) {
						keyName = "LMB";
					} else if ( event.which == 2 ) {
						keyName = "MMB";
					} else {
						keyName = "RMB";
					}
					
					Main.sendEvent( "Inventory.onClickOutsideInventory", keyName, Main.pressedKeys, e.clientY, e.clientX );
				}
			}
		} );
	},
	
	// Перемещается ли вещь в данный момент
	isDragging : function() {
		return Inventory.draggingItem != null;
	},
	
	setVisible : function( setVisible ) {
		if ( typeof( setVisible ) == 'undefined' ) {
			setVisible = true;
		}
		
		if ( setVisible ) {
			$( '#inv' ).addClass( 'visible' );
		} else {
			$( '#inv' ).removeClass( 'visible' );
		}
	}, 
	
	setActive : function( setActive ) {
		if ( typeof( setActive ) == 'undefined' ) {
			setActive = true;
		}
		
		if ( setActive ) {
			$( '#inv' ).addClass( 'active' );
			Inventory.isActive = true;
		} else {
			// Если что-то перетаскиваем, выбрасываем
			if ( Inventory.isDragging() ) {
				Main.sendEvent( "Inventory.dropDragging", Inventory.draggingItem.count );
			}
			$( '#inv' ).removeClass( 'active' );
			
			Tooltip.updateTooltip( null );
			InventorySlot.removeClassOfAll( 'hover' );
			
			Inventory.isActive = false;
		}
	},
	
	// Открыть вкладку меню инвентаря
	setMenuTab : function( tabName ) {
		$( '.inv-menu-tab-header' ).removeClass( 'active' );
		$( '#inv-menu-tab-header-' + tabName ).addClass( 'active' );
		
		$( '.inv-menu-tab' ).removeClass( 'active' );
		$( '#inv-menu-tab-' + tabName ).addClass( 'active' );
	},
	
	// Убрать прогресс-бар использования вещи
	removeItemUsageProgress : function() {
		$( '#inv-usage-progress' ).hide();
	},
	
	// Установить кружок с прогрессом использования вещи
	setItemUsageProgress : function( slotType, slotID, progress ) {
		if ( InventorySlot.exists( slotType, slotID ) ) {
			$( '#inv-usage-progress' ).css( {
				top : $( '#inv-slot-' + slotType + '-' + slotID ).offset().top,
				left : $( '#inv-slot-' + slotType + '-' + slotID ).offset().left
			} );
			
			if ( progress < 0 ) {
				progress = 0;
			} else if ( progress > 100 ) {
				progress = 100;
			}
			
			$( '#inv-usage-progress-circle' ).val( progress ).trigger( 'change' );
			$( '#inv-usage-progress' ).show();
		} else {
			console.error( "Слот ", slotType, slotID, " не существует" )
		}
	},
	
	// Установить текущий активный слот быстрого доступа
	setActiveFastSlot : function( slotID ) {
		if ( InventorySlot.exists( "fast", slotID ) ) {
			//console.log( "Установка слота быстрого доступа " + slotID );
			if ( Inventory.activeFastSlot != null ) {
				$( '#inv-slot-fast-' + Inventory.activeFastSlot ).removeClass( 'active' );
			}
			$( '#inv-slot-fast-' + slotID ).addClass( 'active' );
			Inventory.activeFastSlot = slotID;
		} else {
			console.error( "Слот fast:" + slotID + " не существует" );
		}
	},
	
	// Установить вес инвентаря
	setWeight : function( currentWeight, maxWeight ) {
		var lineWidth = currentWeight / maxWeight * 100;
		if ( lineWidth >= 100 ) {
			lineWidth = 100;
			$( '#inv-weight-line' ).addClass( 'overweight' );
		} else {
			$( '#inv-weight-line' ).removeClass( 'overweight' );
		}
		$( '#inv-weight-line' ).css( 'width', lineWidth + '%' );
		
		$( '#inv-weight-value' ).text( currentWeight + ' / ' + maxWeight );
	},
	
	// Установить конфигурацию контейнера
	setContainer : function( containerType, containerSize ) {
		InventorySlot.removeByType( containerType );
		
		if ( containerSize ) {
			// Установили контейнер, создаем слоты
			for ( var slotID = 1; slotID <= containerSize; slotID++ ) {
				InventorySlot.create( containerType, slotID )
			}
		}
	},
	
	// Установить содержимое контейнера, items { slotID => slotData }
	setContainerItems : function( containerType, items ) {
		InventorySlot.removeItemsBySlotType( containerType );
		
		$.each( items, function( slotID, slotData ) {
			if ( slotID == 0 ) {
				// Нужно передавать строками
				console.error( "setContainerItems принимает только массив вида { '1' => ..., '2' => ... }, с явно указанными ключами (из-за разницы в индексах Lua и JS)" );
				return false;
			}
			InventorySlot.setItem( containerType, slotID, slotData );
		} );
	},
	
	// Установить содержимое одного слота контейнера
	setContainerItem : function( containerType, slotID, itemData ) {
		if ( !itemData ) {
			InventorySlot.removeItem( containerType, slotID );
		} else {
			InventorySlot.setItem( containerType, slotID, itemData );
		}
	},
	
	// Установить вещь, которую тащит игрок, или null (устанавливает Lua)
	setDragging : function( draggingItem ) {
		//console.log( "Установлен Dragging:", draggingItem );
		
		if ( draggingItem == null || draggingItem == false || draggingItem == undefined ) {
			// Прекратили перетаскивание
			//   Убираем данные о dragging
			Inventory.draggingItem = null;
			
			//   Убираем обработку перетаскивания
			$( document ).unbind( 'mousemove', Inventory.handleDragging );
			
			//   Убираем подсказку возле курсора
			$( '#inv-dragging' ).removeClass( 'visible' );
		} else {
			// Начали перетаскивание
			//   Устанавливаем данные о dragging
			Inventory.draggingItem = draggingItem;
			
			//   Добавляем проверку перетаскивания
			$( document ).bind( 'mousemove', Inventory.handleDragging );
			
			//   Показываем подсказку возле курсора
			$( '#inv-dragging' ).html( '' ).append(
				InventorySlot.generateItemElement( draggingItem, true )
			);
			$( '#inv-dragging' ).addClass( 'visible' );
			
			// Обновляем позицию dragging
			Inventory.handleDragging( {
				clientX : GUI.cursorPosition.x,
				clientY : GUI.cursorPosition.y
			} );
		}
	},
	
	// Внутренняя функция, обработка позиции перетаскиваемого предмета
	handleDragging : function( e ) {
		$( '#inv-dragging' ).css( {
			top : e.clientY,
			left : e.clientX
		} );
	}
};
$( document ).ready( Inventory.init );