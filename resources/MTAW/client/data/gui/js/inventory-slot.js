// Слот для вещи
// Создается только в Lua
"use strict";
var InventorySlot = {
	slots : {
		inventory : {},
		fast : {},
		external : {},
		character : {}
	},
	
	hoveredSlot : false,		// Слот, на который сейчас указывает мышка ({ type = ..., id = ... } или false)
	pressedKeys : {},
	
	mousedownButton : false,		// Был вызван mousedown на слоту, но Mouseup еще не было. Переменная содержит название зажатой кнопки
	
	init : function() {
		// Прослушиваем нажатия на клавиши
		$( window ).on( 'keydown keyup', function( e ) {
			if ( e.type == "keydown" ) {
				// Нажата кнопка
				if ( InventorySlot.pressedKeys[ e.which ] != true ) {
					if ( Inventory.isHovered ) {
						// Нажал на кнопку, когда мышка указывала на инвентарь
						if ( InventorySlot.hoveredSlot == false ) {
							// Не на слот инвентаря
							Main.sendEvent( "Inventory.onKeyPress", e.which, Main.pressedKeys, false, false, true, e.clientY, e.clientX );
						} else {
							// На слот инвентаря
							Main.sendEvent( "Inventory.onKeyPress", e.which, Main.pressedKeys, InventorySlot.hoveredSlot.type, InventorySlot.hoveredSlot.id, true, e.clientY, e.clientX );
						}
					} else {
						// Нажал на кнопку, когда мыщка указывала не на инвентарь
						Main.sendEvent( "Inventory.onKeyPress", e.which, Main.pressedKeys, false, false, false, e.clientY, e.clientX );
					}
					
					InventorySlot.pressedKeys[ e.which ] = true;
				}
			} else {
				// Отпущена кнопка
				InventorySlot.pressedKeys[ e.which ] = undefined;
			}
		} );
		
		// Отпустили кнопку мыши
		$( window ).on( 'mouseup', function( e ) {
			if ( InventorySlot.mousedownButton != false ) {
				Main.sendEvent( "Inventory.onMouseup", InventorySlot.mousedownButton, Main.pressedKeys, e.clientY, e.clientX );
				InventorySlot.mousedownButton = false;
			}
		} );
	},
	
	exists : function( slotType, slotID ) {
		return InventorySlot.slots[ slotType ][ slotID ] != undefined;
	},
	
	// Создать слот под вещь
	create : function( slotType, slotID ) {
		if ( InventorySlot.exists( slotType, slotID ) ) {
			console.error( "Слот " + slotType + " " + slotID + " уже занят" );
			return;
		}
		
		var slot = $( '<div class="item-slot" />' ).attr( "id", "inv-slot-" + slotType + "-" + slotID );
		
		if ( slotType == 'inventory' ) {
			$( "#inv-inventory .grid" ).append( slot );
		} else if ( slotType == 'fast' ) {
			$( "#inv-fast .grid" ).append( slot );
		} else if ( slotType == 'external' ) {
			$( "#inv-external .grid" ).append( slot );
		} else if ( slotType == 'character' ) {
			$( "#inv-character .grid" ).append( slot );
		} else {
			console.error( "slotType должен быть inventory, fast, character или external" );
			return;
		}
		
		// Обработчик нажатия на слот
		var lastSlotMousedown = 0;
		$( slot ).on( 'mousedown', function( e ) {
			if ( e.timeStamp - lastSlotMousedown > 40 && !InventorySlot.mousedownButton != false ) {
				var keyName = false;
				if ( event.which == 1 ) {
					keyName = "LMB";
				} else if ( event.which == 2 ) {
					keyName = "MMB";
				} else {
					keyName = "RMB";
				}
				if ( keyName != false ) {
					Main.sendEvent( "Inventory.onMousedownSlot", keyName, slotType, slotID, Main.pressedKeys, event.clientY, event.clientX );
				}
				
				InventorySlot.mousedownButton = keyName;
				lastSlotMousedown = e.timeStamp;
			}
		} );
		
		// Обработчик hover и blur
		$( slot ).on( 'mouseenter mouseleave', function( e ) {
			if ( e.type == 'mouseenter' ) {
				if ( InventorySlot.hoveredSlot != false ) {
					if ( InventorySlot.hoveredSlot.type == slotType && InventorySlot.hoveredSlot.id == slotID ) {
						return;
					}
				}
				
				if ( Inventory.isActive ) {
					InventorySlot.removeClassOfAll( 'hover' );
					InventorySlot.addClass( slotType, slotID, 'hover' );
					
					InventorySlot.hoveredSlot = { type : slotType, id : slotID };
					Main.sendEvent( "Inventory.onSlotHover", slotType, slotID );
				}
			} else {
				InventorySlot.hoveredSlot = false;
				InventorySlot.removeClassOfAll( 'hover' );
			}
		} );
		
		var slotData = {};
		
		slotData.element = slot;
		slotData.type = slotType;
		slotData.id = slotID;
		slotData.item = null;
		
		InventorySlot.slots[ slotType ][ slotID ] = slotData;
	},
	
	// Добавить класс слоту. Например, highlight
	addClass : function( slotType, slotID, className ) {

		if ( InventorySlot.exists( slotType, slotID ) ) {
			$( InventorySlot.slots[ slotType ][ slotID ].element ).addClass( className );
		}
	},
	
	// Убрать класс слоту. Например, highlight
	removeClass : function( slotType, slotID, className ) {
		if ( InventorySlot.exists( slotType, slotID ) ) {
			$( InventorySlot.slots[ slotType ][ slotID ].element ).removeClass( className );
		}
	},
	
	// Убрать класс со всех слотов
	removeClassOfAll : function( className ) {
		$( '.item-slot' ).removeClass( className );
	},
	
	// Удалить слот
	remove : function( slotType, slotID ) {
		if ( InventorySlot.exists( slotType, slotID ) ) {
			$( InventorySlot.slots[ slotType ][ slotID ].element ).remove();
			
			InventorySlot.slots[ slotType ][ slotID ] = undefined;
			
			if ( InventorySlot.hoveredSlot != false ) {
				if ( InventorySlot.hoveredSlot.type == slotType && InventorySlot.hoveredSlot.id == slotID ) {
					InventorySlot.hoveredSlot = false;
				}
			}
		}
	},
	
	// Удалить слоты по типу
	removeByType : function( slotType ) {
		$.each( InventorySlot.slots[ slotType ], function( slotID, slotData ) {
			InventorySlot.remove( slotType, slotID );
		} );
	},
	
	// Получить элемент, который является содержимым слота (используется в setItem и grabbing)
	// Если noInfo == true, информация о вещи не будет добавлена (полезно для dragging)
	generateItemElement : function( itemData, noInfo ) {
		if ( noInfo == undefined ) { 
			noInfo = false;
		}
		
		var itemElement = $( '<div class="item-slot-element" />' );
		if ( itemData.stack != 1 ) {
			itemElement.append(
				$( '<div class="item-slot-element-count" />' ).text( itemData.count )
			);
		}
		
		$( itemElement ).css( {
			backgroundImage : 'url(../item/icon/' + itemData.icon + '.png)'
		} );
		
		// Добавляем полосу состояния, если такой параметр есть
		if ( itemData.quality != undefined ) {
			var qualityElement = $( '<div class="item-slot-element-quality" />' )
				.css( 'width', ( itemData.quality * 100 ) + '%' );
				
			if ( itemData.quality < 0.25 ) {
				qualityElement.addClass( 'quality-red' );
			} else if ( itemData.quality < 0.5 ) {
				qualityElement.addClass( 'quality-orange' );
			} else if ( itemData.quality < 0.75 ) {
				qualityElement.addClass( 'quality-yellow' );
			} else {
				qualityElement.addClass( 'quality-green' );
			}
			itemElement.append( 
				$( '<div class="item-slot-element-quality-wrap" />' ).append( qualityElement ) 
			);
		}
		
		// Добавляем информацию о предмете
		if ( !noInfo ) {
			var infoElement = $( '<div class="item-slot-info" />' );
			
			$( infoElement ).append(
				$( '<div class="name" />' ).html( itemData.name ),
				$( '<div class="description" />' ).html( itemData.descr )
			);
			
			if ( itemData.stats != undefined ) {
				// Есть статистика
				var statsElement = $( '<div class="item-slot-info-stats" />' );
				
				$.each( itemData.stats, function( name, statData ) {
					if ( statData[ 0 ] == "string" ) {
						statsElement.append( 
							$( '<div class="stat" />' ).append(
								$( '<div class="stat-name" />' ).html( name ),
								$( '<div class="stat-value" />' ).html( statData[ 1 ] )
							)	
						);
					} else if ( statData[ 0 ] == "progress" ) {
						statsElement.append( 
							$( '<div class="stat" />' ).append(
								$( '<div class="stat-name" />' ).html( name ),
								$( '<div class="stat-value" />' ).append(
									$( '<div class="progress" />' ).append(
										$( '<div class="wrap" />' ).append(
											$( '<div class="line" />' ).css( 'width', ( statData[ 1 ] / statData[ 2 ] ) * 100 + '%' ).append( statData[ 1 ] )
										),
										$( '<div class="maxValue" />' ).append( statData[ 2 ] )
									)
								)
							)	
						);
					}
				} );
				
				infoElement.append( statsElement );
			}
			
			itemElement.append( 
				$( '<div class="item-slot-info-wrap" />' ).append( infoElement ) 
			);
		}
		
		return itemElement;
	},
	
	// Передается уже испеченная информация о вещи (название, значок, размер стека, описание и прочее)
	setItem : function( slotType, slotID, itemData ) {
		if ( !InventorySlot.exists( slotType, slotID ) ) {
			console.error( "Слот с индексом " + slotID + " не сушествует" );
		} else {
			var slotData = InventorySlot.slots[ slotType ][ slotID ];
			
			slotData.element.html( '' );
			
			//console.log( itemData );
			
			var itemElement = InventorySlot.generateItemElement( itemData );
			
			slotData.item = itemData;
			slotData.element.append( itemElement );
			$( slotData.element ).addClass( 'contains-item' );
		}
	},
	
	// Получить вещь из слота или null
	getItem : function( slotType, slotID ) {
		if ( !InventorySlot.exists( slotType, slotID ) ) {
			console.error( "Слот с индексом " + index + " не сушествует" );
		} else {
			return InventorySlot.slots[ slotType ][ slotID ].item;
		}
	},
	
	// Убрать вещь из слота
	removeItem : function( slotType, slotID ) {
		if ( !InventorySlot.exists( slotType, slotID ) ) {
			console.error( "Слот с индексом " + index + " не сушествует" );
		} else {
			if ( InventorySlot.slots[ slotType ][ slotID ].item != null ) {
				InventorySlot.slots[ slotType ][ slotID ].item = null;
				InventorySlot.slots[ slotType ][ slotID ].element.html( '' );
				InventorySlot.slots[ slotType ][ slotID ].element.removeClass( 'contains-item' );
			}
		}
	},
	
	// Убрать все вещи из слотов определенного типа
	removeItemsBySlotType : function( slotType ) {
		$.each( InventorySlot.slots[ slotType ], function( k, v ) {
			InventorySlot.removeItem( slotType, k );
		} );
	}
};
$( document ).ready( InventorySlot.init );