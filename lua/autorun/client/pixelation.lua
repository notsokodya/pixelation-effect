local function init()
	hook.Remove("Initialize", "pixelation_fix")

	-- RenderTargets & Materials
	local rt, rt2, scrMat, scrMat2
	local function initRT()
		local w, h = ScrW(), ScrH()

		rt = GetRenderTargetEx("pixels_rt", w, h, RT_SIZE_NO_CHANGE, MATERIAL_RT_DEPTH_SEPARATE, bit.bor(1, 256), 0, IMAGE_FORMAT_BGRA8888)
		rt2 = GetRenderTargetEx("pixels_scr", w, h, RT_SIZE_NO_CHANGE, MATERIAL_RT_DEPTH_SEPARATE, bit.bor(1, 256), 0, IMAGE_FORMAT_BGRA8888)
		scrMat = CreateMaterial("pixelation_nofilter", "UnlitGeneric", {
			["$basetexture"] = rt:GetName(),
		})
		scrMat2 = CreateMaterial("pixelation_pixelated", "UnlitGeneric", {
			["$basetexture"] = rt2:GetName(),
		})

		-- Materials fix
		scrMat:SetInt("$flags", bit.bor(scrMat:GetInt("$flags"), 32768))
		scrMat2:SetInt("$flags", bit.bor(scrMat2:GetInt("$flags"), 32768))
	end

	-- Convars
	local enable = CreateClientConVar("pp_pixelation", "0", false, false, "Toggle pixelation")
	local level = CreateClientConVar("pp_pixelation_level", "4", true, false, "Pixelation level", 1)

	-- Render
	local view = {}
	view.x = 0
	view.y = 0
	hook.Add("RenderScene", "pixels", function(pos, ang)
		local w, h = ScrW(), ScrH() -- maybe player can change his game resolution no? - Zvbhrf

		if enable:GetInt() == 0 then return end

		if not rt or not rt2 or not scrMat or not scrMat2 then
			return initRT()
		end

		local pixel_level = level:GetInt()
		if pixel_level < 2 then return end -- looks like default gmod
		
		view.w = w
		view.h = h
		view.origin = pos
		view.angles = ang
		view.drawhud = true

		local oldrt = render.GetRenderTarget()
		local wPx, hPx = math.ceil(w/pixel_level), math.ceil(h/pixel_level)

		-- Removing filtering
		render.SetRenderTarget(rt)
			render.Clear(0, 0, 0, 255, true)
			render.ClearDepth()
			render.ClearStencil()
			render.RenderView(view)
		render.SetRenderTarget(oldrt)

		scrMat:SetTexture("$basetexture", rt)

		-- Capturing low resolution unfiltered rendertarget
		render.PushRenderTarget(rt2, 0, 0, wPx, hPx)
			cam.Start2D()
				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawRect(0, 0, 16, 16)
				surface.SetMaterial(scrMat)
				surface.DrawTexturedRect(0, 0, wPx, hPx)
			cam.End2D()
		render.PopRenderTarget()

		scrMat2:SetTexture("$basetexture", rt2)

		-- Rendering pixelated rendertarget
		render.SetMaterial(scrMat2)
		render.DrawScreenQuadEx(0, 0, math.ceil(w*pixel_level), math.ceil(h*pixel_level))
		hook.Run("RenderScreenspaceEffects") -- post-processing
		render.RenderHUD(0, 0, view.w, view.h)

		return true
	end)
	
	hook.Add("OnScreenSizeChanged", "pixelation_fix_mat", initRT) -- fixes rt material on resolution change -- Zvbhrf
end

hook.Add("Initialize", "pixelation_fix", init) --init()

-- Adding my thing to post-process folder
list.Set("PostProcess", "Pixelation", {
	icon = "gui/postprocess/pixelation.png",
	convar = "pp_pixelation",
	category = "#shaders_pp",

	cpanel = function(CPanel)
		CPanel:AddControl("Header", {Description = "Pixelates your screen"})
		CPanel:AddControl("CheckBox", {Label = "Enable", Command = "pp_pixelation"})

		local params = {Options = {}, CVars = {}, MenuButton = "1", Folder = "pixelation"}
		params.Options["#preset.default"] = {
			pp_pixelation_level = 4
		}
		params.CVars = table.GetKeys(params.Options["#preset.default"])
		CPanel:AddControl("ComboBox", params)

		CPanel:AddControl("Slider", {
			Label = "Pixelation Level",
			Command = "pp_pixelation_level",
			Type = "Integer",
			Min = "2", 
			Max = "64"
		})
	end
})