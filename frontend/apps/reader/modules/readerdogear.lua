local BD = require("ui/bidi")
local Device = require("device")
local Geom = require("ui/geometry")
local IconWidget = require("ui/widget/iconwidget")
local RightContainer = require("ui/widget/container/rightcontainer")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Screen = Device.screen

local ReaderDogear = WidgetContainer:extend{}

function ReaderDogear:init()
    -- This image could be scaled for DPI (with scale_for_dpi=true, scale_factor=0.7),
    -- but it's as good to scale it to a fraction (1/32) of the screen size.
    -- For CreDocument, we should additionally take care of not exceeding margins
    -- to not overwrite the book text.
    -- For other documents, there is no easy way to know if valuable content
    -- may be hidden by the icon (kopt's page_margin is quite obscure).
    self.dogear_min_size = math.ceil(math.min(Screen:getWidth(), Screen:getHeight()) / 40)
    self.dogear_max_size = math.ceil(math.min(Screen:getWidth(), Screen:getHeight()) / 32)
    self.dogear_size = nil
    self.dogear_y_offset = 0
    self.top_pad = nil
    self:setupDogear()
    self:resetLayout()
end

function ReaderDogear:setupDogear(new_dogear_size)
    if not new_dogear_size then
        new_dogear_size = self.dogear_max_size
    end
    if new_dogear_size ~= self.dogear_size then
        self.dogear_size = new_dogear_size
        if self[1] then
            self[1]:free()
        end
        self.top_pad = VerticalSpan:new{width = self.dogear_y_offset}
        self.vgroup = VerticalGroup:new{
            self.top_pad,
            IconWidget:new{
                icon = "dogear.alpha",
                rotation_angle = BD.mirroredUILayout() and 90 or 0,
                width = self.dogear_size,
                height = self.dogear_size,
                alpha = true, -- Keep the alpha layer intact
            }
        }
        self[1] = RightContainer:new{
            dimen = Geom:new{w = Screen:getWidth(), h = self.dogear_y_offset + self.dogear_size},
            self.vgroup
        }
    end
end

function ReaderDogear:onReadSettings(config)
    if not self.ui.document.info.has_pages then
        -- Adjust to CreDocument margins (as done in ReaderTypeset)
        local h_margins = config:readSetting("copt_h_page_margins")
                       or G_reader_settings:readSetting("copt_h_page_margins")
                       or G_defaults:readSetting("DCREREADER_CONFIG_H_MARGIN_SIZES_MEDIUM")
        local t_margin = config:readSetting("copt_t_page_margin")
                      or G_reader_settings:readSetting("copt_t_page_margin")
                      or G_defaults:readSetting("DCREREADER_CONFIG_T_MARGIN_SIZES_LARGE")
        local b_margin = config:readSetting("copt_b_page_margin")
                      or G_reader_settings:readSetting("copt_b_page_margin")
                      or G_defaults:readSetting("DCREREADER_CONFIG_B_MARGIN_SIZES_LARGE")
        local margins = { h_margins[1], t_margin, h_margins[2], b_margin }
        self:onSetPageMargins(margins)
    end
end

function ReaderDogear:onSetPageMargins(margins)
    if self.ui.document.info.has_pages then
        -- we may get called by readerfooter (when hiding the footer)
        -- on pdf documents and get margins=nil
        return
    end
    local margin_top, margin_right = margins[2], margins[3]
    -- As the icon is squared, we can take the max() instead of the min() of
    -- top & right margins and be sure no text is hidden by the icon
    -- (the provided margins are not scaled, so do as ReaderTypeset)
    local margin = Screen:scaleBySize(math.max(margin_top, margin_right))
    local new_dogear_size = math.min(self.dogear_max_size, math.max(self.dogear_min_size, margin))
    self:setupDogear(new_dogear_size)
end

function ReaderDogear:updateDogearOffset()
    if self.ui.document.info.has_pages then
        return
    end
    self.dogear_y_offset = 0
    if self.view.view_mode == "page" then
        self.dogear_y_offset = self.ui.document:getHeaderHeight()
    end
    -- Update components heights and positionnings
    if self[1] then
        self[1].dimen.h = self.dogear_y_offset + self.dogear_size
        self.top_pad.width = self.dogear_y_offset
        self.vgroup:resetLayout()
    end
end

function ReaderDogear:onUpdatePos()
    -- Catching the top status bar toggling with :onSetStatusLine()
    -- would be too early. But "UpdatePos" is sent after it has
    -- been applied
    self:updateDogearOffset()
end

function ReaderDogear:onChangeViewMode()
    -- No top status bar when switching between page and scroll mode
    self:updateDogearOffset()
end

function ReaderDogear:resetLayout()
    local new_screen_width = Screen:getWidth()
    if new_screen_width == self._last_screen_width then return end
    self._last_screen_width = new_screen_width

    self[1].dimen.w = new_screen_width
end

function ReaderDogear:onSetDogearVisibility(visible)
    self.view.dogear_visible = visible
    return true
end

return ReaderDogear
