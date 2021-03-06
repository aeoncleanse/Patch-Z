--****************************************************************************
--**
--**  File     :  /modules/ScalableOvercharge.lua
--**  Author(s):  Michael Søndergaard <sheeo@sheeo.dk>
--**
--**  Summary  :  New overcharge weapon that drains up to a certain cap of
--**              energy and deals damage according to how much energy is spent
--**
--**  Copyright © 2014 Michael Søndergaard
--**              All rights reserved
--**
--****************************************************************************

local DefaultWeapons = import('/lua/sim/DefaultWeapons.lua')
local DefaultProjectileWeapon = DefaultWeapons.DefaultProjectileWeapon

function OverchargeCost(stored, ratio)
    local maximum = (stored/ratio)/2 -- Half of energy stored is the maximum we can output

    return math.min(stored, maximum)
end

function OverchargeDamage(spent)
    local map = (2*spent / 100000) * 10
    local scale = 1 / (1 + math.pow(2.71828182, -(map-5)))
    return scale * 25000
end

local function GetEnergyFromBrain(brain)
    local stored, ratio = brain:GetEconomyStored('ENERGY'), brain:GetEconomyStoredRatio('ENERGY')
    return stored, ratio, stored / ratio
end

ScalableOvercharge = Class(DefaultProjectileWeapon) {
    StartEconomyDrain = function(self)
        if self.FirstShot then return end

        local energyStored, energyRatio, energyStorage = GetEnergyFromBrain(GetArmyBrain(self.unit:GetArmy()))

        local cost = OverchargeCost(energyStored, energyRatio)
        LOG("Overcharge cost " .. cost)
        CreateEconomyEvent(self.unit, cost, 0, 1)

        self.FirstShot = true
    end,
    PauseOvercharge = function(self)
        local wait = math.max(self.LatestOverchargeDmg/4000, 2)
        if not self.unit:IsOverchargePaused() then
            self.unit:SetOverchargePaused(true)
            LOG("OC paused for " .. wait .. " seconds")
            WaitSeconds(wait)
            self.unit:SetOverchargePaused(false)
        end
    end,
    CreateProjectileAtMuzzle = function(self, muzzle)
        local proj = DefaultProjectileWeapon.CreateProjectileAtMuzzle(self, muzzle)
        LOG("Overcharge dmg: " .. repr(proj.DamageData.DamageAmount))
        return proj
    end,
    GetDamageTable = function(self)
        local normalDamageTable = DefaultProjectileWeapon.GetDamageTable(self)

        local energyStored, energyRatio, energyStorage = GetEnergyFromBrain(GetArmyBrain(self.unit:GetArmy()))

        local dmg = OverchargeDamage(OverchargeCost(energyStored, energyRatio))
        self.LatestOverchargeDmg = dmg
        normalDamageTable.DamageAmount = dmg
        return normalDamageTable
    end
}
