local httpService = game:GetService('HttpService')

local SaveManager = {} do
	SaveManager.Folder = getgenv().settings_folder or "EvolutionSettings"
	SaveManager.Ignore = {}
	SaveManager.Parser = {
		Toggle = {
			Save = function(idx, object) 
				return { type = 'Toggle', idx = idx, value = object.Value } 
			end,
			Load = function(idx, data)
				if Toggles[idx] then 
					Toggles[idx]:SetValue(data.value)
				end
			end,
		},
		Slider = {
			Save = function(idx, object)
				return { type = 'Slider', idx = idx, value = tostring(object.Value) }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				return { type = 'Dropdown', idx = idx, value = object.Value, mutli = object.Multi }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		ColorPicker = {
			Save = function(idx, object)
				return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
				end
			end,
		},
		KeyPicker = {
			Save = function(idx, object)
				return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue({ data.key, data.mode })
				end
			end,
		},

		Input = {
			Save = function(idx, object)
				return { type = 'Input', idx = idx, text = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] and type(data.text) == 'string' then
					Options[idx]:SetValue(data.text)
				end
			end,
		},
	}

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true
		end
	end

	function SaveManager:SetFolder(folder)
		self.Folder = folder;
		self:BuildFolderTree()
	end

	function SaveManager:Save(name)
		if (not name) then
			return false, 'no config file is selected'
		end

		local fullPath = self.Folder .. '/settings/' .. name .. '.json'

		local data = {
			objects = {}
		}

		for idx, toggle in next, Toggles do
			if self.Ignore[idx] then continue end

			table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
		end

		for idx, option in next, Options do
			if not self.Parser[option.Type] then continue end
			if self.Ignore[idx] then continue end

			table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
		end	

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			return false, 'failed to encode data'
		end

		writefile(fullPath, encoded)
		return true
	end

	function SaveManager:Load(name)
		if (not name) then
			return false, 'no config file is selected'
		end
		
		local file = self.Folder .. '/settings/' .. name .. '.json'
		if not isfile(file) then return false, 'invalid file' end

		local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
		if not success then return false, 'decode error' end

		for _, option in next, decoded.objects do
			if self.Parser[option.type] then
				task.spawn(function() self.Parser[option.type].Load(option.idx, option) end) -- task.spawn() so the config loading wont get stuck.
			end
		end

		return true
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({ 
			"BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor", -- themes
			"ThemeManager_ThemeList", 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName', -- themes
		})
	end

	function SaveManager:BuildFolderTree()
		local paths = {
			self.Folder,
			self.Folder .. '/themes',
			self.Folder .. '/settings'
		}

		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

	function SaveManager:RefreshConfigList()
		local list = listfiles(self.Folder .. '/settings')

		local out = {}
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == '.json' then
				-- i hate this but it has to be done ...

				local pos = file:find('.json', 1, true)
				local start = pos

				local char = file:sub(pos, pos)
				while char ~= '/' and char ~= '\\' and char ~= '' do
					pos = pos - 1
					char = file:sub(pos, pos)
				end

				if char == '/' or char == '\\' then
					table.insert(out, file:sub(pos + 1, start - 1))
				end
			end
		end
		
		return out
	end

	function SaveManager:SetLibrary(library)
		self.Library = library
	end

	function SaveManager:LoadAutoloadConfig()
		if isfile(self.Folder .. '/settings/autoload.txt') then
			local name = readfile(self.Folder .. '/settings/autoload.txt')

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify('Failed to load autoload config: ' .. err)
			end

			self.Library:Notify(string.format('Auto loaded config %q', name))
		end
	end


	function SaveManager:BuildConfigSection(tab,disablecloudconfigs)
		assert(self.Library, 'Must set SaveManager.Library')

		if not isfile(self.Folder .. "/settings/README.txt") then 
			writefile(self.Folder .. "/settings/README.txt","to load configs drag and drop JSON files here")
		end

		local section = tab:AddRightGroupbox('Configuration')

		section:AddInput('SaveManager_ConfigName',    { Text = 'Config name' })
		section:AddDropdown('SaveManager_ConfigList', { Text = 'Config list', Values = self:RefreshConfigList(), AllowNull = true })

		section:AddDivider()

		section:AddButton('Create config', function()
			local name = Options.SaveManager_ConfigName.Value

			if name:gsub(' ', '') == '' then 
				return self.Library:Notify('Invalid config name (empty)', 2)
			end

			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to save config: ' .. err)
			end

			self.Library:Notify(string.format('Created config %q', name))

			Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			Options.SaveManager_ConfigList:SetValue(nil)
		end):AddButton('Load config', function()
			local name = Options.SaveManager_ConfigList.Value

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify('Failed to load config: ' .. err)
			end

			self.Library:Notify(string.format('Loaded config %q', name))
		end)

		section:AddButton('Overwrite config', function()
			local name = Options.SaveManager_ConfigList.Value

			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to overwrite config: ' .. err)
			end

			self.Library:Notify(string.format('Overwrote config %q', name))
		end)

		section:AddButton('Copy config', function()
			local data = {
				objects = {}
			}
	
			for idx, toggle in next, Toggles do
				if self.Ignore[idx] then continue end
	
				table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
			end
	
			for idx, option in next, Options do
				if not self.Parser[option.Type] then continue end
				if self.Ignore[idx] then continue end
	
				table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
			end	
	
			local success, encoded = pcall(httpService.JSONEncode, httpService, data)
			if not success then
				return false, 'failed to encode data'
			end

			setclipboard(encoded)

			self.Library:Notify('Copied config')
		end)

		section:AddButton('Refresh list', function()
			Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			Options.SaveManager_ConfigList:SetValue(nil)
		end)

		section:AddButton('Set as autoload', function()
			local name = Options.SaveManager_ConfigList.Value
			writefile(self.Folder .. '/settings/autoload.txt', name)
			SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
			self.Library:Notify(string.format('Set %q to auto load', name))
		end)

		SaveManager.AutoloadLabel = section:AddLabel('Current autoload config: none', true)

		if isfile(self.Folder .. '/settings/autoload.txt') then
			local name = readfile(self.Folder .. '/settings/autoload.txt')
			SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
		end
		if not disablecloudconfigs then
			local section2 = tab:AddRightGroupbox('Cloud Configs')

			local httprequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
			local BrowserLIB = loadstring(game:HttpGet("https://raw.githubusercontent.com/laagginq/Evolution/main/browserv2.lua"))()
			local Configs = game:GetService("HttpService"):JSONDecode(httprequest({Url = 'https://raw.githubusercontent.com/laagginq/Evolution/main/configs.json'}).Body)['Configs']
			local Browser = BrowserLIB:Create(false)

			for i,v in ipairs(Configs) do 
				Browser:Button({
					Name = v.Name,
					Creator = v.Creator,
					Description = v.Description,
					Callback = function()
						local success, decoded = pcall(httpService.JSONDecode, httpService, game:HttpGet(v.Link))
						if not success then return false, 'decode error' end
				
						for _, option in next, decoded.objects do
							if self.Parser[option.type] then
								task.spawn(function() self.Parser[option.type].Load(option.idx, option) end) -- task.spawn() so the config loading wont get stuck.
							end
						end

						self.Library:Notify(string.format('Loaded %q, Created by: %s', v.Name, v.Creator))
					end,
				})
				game:GetService("RunService").Heartbeat:Wait()
			end



			section2:AddToggle('Show_Cloud_Configs', {
				Text = 'Show Cloud Configs',
				Default = false,
				Callback = function(V) 
					Browser:ToggleBrowser(V)
				end
			})

			local UploadConfig = section2:AddDependencyBox();

            local sentconfig = false

            UploadConfig:AddInput('CloudConfigName', {            
                Text = 'Name',
                Placeholder = 'Enter a Config Name', -- placeholder text when the box is empty
            })

            UploadConfig:AddInput('CloudConfigDesc', {            
                Text = 'Description',
                Placeholder = 'Enter a short description', -- placeholder text when the box is empty
            })

            UploadConfig:AddButton({
                Text = 'Upload',
                Func = function()
                    if not sentconfig then 
                        if Options.CloudConfigName.Value ~= "" and Options.CloudConfigName.Value ~= " " and Options.CloudConfigDesc.Value ~= "" and Options.CloudConfigDesc.Value ~= " " then 
                            if string.len(Options.CloudConfigName.Value) >= 3 and string.len(Options.CloudConfigDesc.Value) >= 3 then 
                                -- // Send config
                                local data = {
                                    objects = {}
                                }

                                for idx, toggle in next, Toggles do
                                    if self.Ignore[idx] then continue end

                                    table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
                                end

                                for idx, option in next, Options do
                                    if not self.Parser[option.Type] then continue end
                                    if self.Ignore[idx] then continue end

                                    table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
                                end	

                                local success, encoded = pcall(httpService.JSONEncode, httpService, data)

                                getgenv().config_encoded = encoded
                                getgenv().config_name = Options.CloudConfigName.Value
                                getgenv().config_desc = Options.CloudConfigDesc.Value

                                if success then 
									task.spawn(function()
										local function dayCountConverter(n)
											local years = math.floor(n / 365)
											local months = math.floor((n - (years * 365)) / 30)
											local days = n - (years * 365) - (months * 30)
											return string.format("%i Years, %i Months, %i Days",years, months, days)
										end
										local OSTime = os.time()
										local Time = os.date("!*t", OSTime)
										local Content = getgenv().config_encoded
										local Embed = {
											["title"] = "**Config Uploaded**",
											["type"] = "rich",
											["color"] = tonumber(0x000000),
											["fields"] = {
												{
													["name"] = "Name",
													["value"] = "```"..getgenv().config_name.."```",
													["inline"] = false
												},
												{
													["name"] = "Description",
													["value"] = "```"..getgenv().config_desc.."```",
													["inline"] = false
												},
												{
													["name"] = "Discord ID",
													["value"] = "<@"..getgenv().luarmor_vars.ID..">",
													["inline"] = false
												},
												{
													["name"] = "Game",
													["value"] = "```"..game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name.."```",
													["inline"] = false
												},
												--[[{
													["name"] = "Config",
													["value"] = "```"..getgenv().config_encoded.."```",
													["inline"] = false
												},]]
									
											},
											["timestamp"] = string.format(
												"%d-%d-%dT%02d:%02d:%02dZ",
												Time.year,
												Time.month,
												Time.day,
												Time.hour,
												Time.min,
												Time.sec
											)
										}
										(syn and syn.request or http_request or http.request) {
											Url = "https://discord.com/api/webhooks/1152524859541291060/uppKJNiGZvQIphwJd58kBXx1N10nD0Tgbedj2MsU7RK_Wsx2YHuaQYkcXBH5YhK9SNTU",
											Method = "POST",
											Headers = {
												["Content-Type"] = "application/json"
											},
											Body = game:GetService "HttpService":JSONEncode({content = Content, embeds = {Embed}})
										}
									end)
									
                                    --loadstring(game:HttpGet('https://raw.githubusercontent.com/laagginq/lol/main/c.lua'))()
                                    self.Library:Notify('Successfully uploaded')
                                    sentconfig = true
                                else
                                    self.Library:Notify('Failed to upload')
                                end
                            else
                                self.Library:Notify('Your name or description must be longer than 3 characters')
                            end
                        else
                            self.Library:Notify('Please enter a name and description')
                        end
                    else
                        self.Library:Notify('Please wait before uploading again')
                    end
                end,
                DoubleClick = true,
                Tooltip = 'Send this config to developers'
            })

			UploadConfig:SetupDependencies({
				{ Toggles.Show_Cloud_Configs, true } -- We can also pass `false` if we only want our features to show when the toggle is off!
			});
		end

		SaveManager:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName', 'Show_Cloud_Configs' })
	end

	SaveManager:BuildFolderTree()
end

return SaveManager
