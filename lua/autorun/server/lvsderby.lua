// Based on the [simfphys] Better Crash Damage & Derby Support mod by D MAS
local hasSimfphys
if simfphys then
    hasSimfphys = true 
else 
    hasSimfphys = false 
end

hook.Add("OnEntityCreated", "LVS_DerbyCollision", function(ent)
    if IsValid(ent) and hasSimfphys and not ent:GetClass():match("^lvs") then // 💀
            if not simfphys.IsCar(ent) then
                return 
            end
    elseif not IsValid(ent) or (not ent:GetClass():match("^lvs") or ent:GetClass() == "lvs_wheeldrive_fueltank" or ent:GetClass() == "lvs_item_mine") then
        return 
    end
    timer.Simple(0, function()
        ent.PhysicsCollideBack = ent.PhysicsCollide
        ent.PhysicsCollide = function(self, data, physobj)
            if self.PhysicsCollideBack then self:PhysicsCollideBack(data, physobj) end // use original PhysicsCollide func in order not to break visual damage on some cars
            if data.DeltaTime < 0.2 then return end
            local speed = data.Speed
            local mass = 1
            local hitEnt = data.HitEntity

            if IsValid(hitEnt) and not hitEnt:IsWorld() then
                mass = math.Clamp(data.HitObject:GetMass() / physobj:GetMass(), 0, 1)
            end

            local divide
            if not hasSimfphys then
                divide = 20000 // try to balance damage. lvs cars has less hp than simfphys ones
            else
                divide = simfphys.IsCar(self) and 5000 or 20000
            end

            local dmg = (speed * speed * mass) / divide

            if not dmg or dmg < 1 then return end

            local pos = data.HitPos
            local normal = data.HitNormal
            local attacker = hitEnt

            if hitEnt:GetClass():match("^lvs") then
                local vel = data.OurOldVelocity
                local tvel = data.TheirOldVelocity
                local dif = data.OurNewVelocity - tvel
                local dot = -dif:Dot(tvel:GetNormalized())
                dmg = dmg * math.Clamp(dot / speed, 0.1, 0.9) * 1.5
            end

            if hasSimfphys then // 💀
                if simfphys.IsCar(hitEnt) then
                    local vel = data.OurOldVelocity
                    local tvel = data.TheirOldVelocity
                    local dif = data.OurNewVelocity - tvel
                    local dot = -dif:Dot(tvel:GetNormalized())
                    dmg = dmg * math.Clamp(dot / speed, 0.1, 0.9) * 1.5
                end
            end

            if self:GetClass() == "lvs_wheeldrive_wheel" then // deal damage by wheel, but don't take damage with wheel
                return
            end

            local effectdata = EffectData()
	        effectdata:SetOrigin(pos - normal)
	        effectdata:SetNormal(-normal)
	        util.Effect("stunstickimpact", effectdata, true, true)

            if (hasSimfphys) then // lvs has impact sounds, and simfphys has not... if I'm didn't missed them lol
                if simfphys.IsCar(self) then
			        if dmg >= 100 then
				        sound.Play(Sound("MetalVehicle.ImpactHard"), pos)
			        elseif dmg >= 10 then
				        sound.Play(Sound("MetalVehicle.ImpactSoft"), pos)
			        end
                end
            end

            local dmginfo = DamageInfo()
            dmginfo:SetDamage(dmg)
            dmginfo:SetAttacker(attacker)
            dmginfo:SetInflictor(self)
            dmginfo:SetDamageType(DMG_CRUSH + DMG_VEHICLE)
            dmginfo:SetDamagePosition(pos)
            local force = (self:GetPos() - pos):GetNormalized() * dmg * physobj:GetMass() * 100
            dmginfo:SetDamageForce(force)
            if hasSimfphys then
                if simfphys.IsCar(self) then
                    self:TakeDamageInfo(dmginfo)
                    return
                end
            end
            if not self.Base:match("^lvs_base_wheeldrive") then
                self:TakeDamageInfo(dmginfo)
            else // take damage to engine if it's lvs car
                eng = self:GetEngine()
                if not IsValid(eng) then 
                    self:TakeDamageInfo(dmginfo)
                    return 
                end
                dmginfo:SetDamage(dmg * 0.12)
                eng:TakeTransmittedDamage(dmginfo)
            end
        end
    end)
end)
