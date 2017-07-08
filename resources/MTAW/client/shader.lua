--------------------------------------------------------------------------------
--<[ Модуль Shader ]>-----------------------------------------------------------
--------------------------------------------------------------------------------
Shader = {
	teaEncryptionKey = "bTZqnDdebzhdTboX";
	
	-- Возвращает dxShader или nil, если такого файла нет (обертка dxCreateShader, необходимая для защиты исходного кода шейдеров в релизе)
	-- > filepath string - оригинальный путь к файлу шейдера (.fx)
	-- > priority number / nil - приоритет шейдера по отношению к другим примененным шейдерам (см. https://wiki.mtasa.com/wiki/DxCreateShader)
	-- > maxDistance number / nil - максимальная дистанция, с которой видно действие шейдера (см. https://wiki.mtasa.com/wiki/DxCreateShader)
	-- > layered bool / nil - будет ли шейдер отрисовываться в отдельный слой (см. https://wiki.mtasa.com/wiki/DxCreateShader)
	-- > elementTypes string / nil - список типов элементов (через запятую), на которых будет работать шейдер (см. https://wiki.mtasa.com/wiki/DxCreateShader)
	-- = shaderElement / nil shader
	create = function( filepath, priority, maxDistance, layered, elementTypes )
		if ( DEBUG_MODE ) then
			-- В режиме отладки загружаем исходники
			return dxCreateShader( filepath, priority, maxDistance, layered, elementTypes )
		else 
			-- В релизе - загружаем шейдер из массива шейдеров (который генерируется компилятором), записываем в файл, создаем шейдер и удаляем файл
			if ( ARR_Shaders[ filepath ] ~= nil ) then
				-- Такой шейдер существует
				local shaderContents = base64Decode( ARR_Shaders[ filepath ] )
				local file = fileCreate( filepath )
				fileWrite( file, shaderContents )
				fileClose( file )
				
				local s = dxCreateShader( filepath, priority, maxDistance, layered, elementTypes )
				
				fileDelete( filepath )
				
				return s
			else
				-- Такого шейдера нет
				return nil
			end
		end
	end;
}