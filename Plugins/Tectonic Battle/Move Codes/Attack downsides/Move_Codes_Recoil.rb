#===============================================================================
# User takes recoil damage equal to 1/5 of the damage this move dealt.
#===============================================================================
class PokeBattle_Move_599 < PokeBattle_RecoilMove
    def recoilFactor; return 0.2; end
end

#===============================================================================
# User takes recoil damage equal to 1/4 of the damage this move dealt.
#===============================================================================
class PokeBattle_Move_0FA < PokeBattle_RecoilMove
    def recoilFactor;  return 0.25; end
end

#===============================================================================
# User takes recoil damage equal to 1/3 of the damage this move dealt.
#===============================================================================
class PokeBattle_Move_0FB < PokeBattle_RecoilMove
    def recoilFactor;  return (1.0 / 3.0); end
end

#===============================================================================
# User takes recoil damage equal to 1/3 of the damage this move dealt.
# May paralyze the target. (Volt Tackle)
#===============================================================================
class PokeBattle_Move_0FD < PokeBattle_RecoilMove
    def recoilFactor;  return (1.0 / 3.0); end

    def pbAdditionalEffect(user, target)
        return if target.damageState.substitute
        target.applyNumb(user) if target.canNumb?(user, false, self)
    end

    def getTargetAffectingEffectScore(user, target)
        return getNumbEffectScore(user, target)
    end
end

#===============================================================================
# User takes recoil damage equal to 1/3 of the damage this move dealt.
# May burn the target. (Flare Blitz)
#===============================================================================
class PokeBattle_Move_0FE < PokeBattle_RecoilMove
    def recoilFactor; return (1.0 / 3.0); end

    def pbAdditionalEffect(user, target)
        return if target.damageState.substitute
        target.applyBurn(user) if target.canBurn?(user, false, self)
    end

    def getTargetAffectingEffectScore(user, target)
        return getBurnEffectScore(user, target)
    end
end

#===============================================================================
# User takes recoil damage equal to 1/2 of the damage this move dealt.
# (Head Smash, Light of Ruin)
#===============================================================================
class PokeBattle_Move_0FC < PokeBattle_RecoilMove
    def recoilFactor;  return 0.5; end
end

#===============================================================================
# User takes recoil damage equal to 2/3 of the damage this move dealt.
# (Head Charge)
#===============================================================================
class PokeBattle_Move_502 < PokeBattle_RecoilMove
    def recoilFactor; return (2.0 / 3.0); end
end

#===============================================================================
# 100% Recoil Move (Thunder Belly)
#===============================================================================
class PokeBattle_Move_56B < PokeBattle_RecoilMove
    def recoilFactor; return 1.0; end
end

#===============================================================================
# If attack misses, user takes crash damage of 1/2 of max HP.
# (High Jump Kick, Jump Kick)
#===============================================================================
class PokeBattle_Move_10B < PokeBattle_Move
    def recoilMove?;        return true; end
    def unusableInGravity?; return true; end

    def pbCrashDamage(user)
        recoilDamage = user.totalhp / 2.0
        recoilMessage = _INTL("{1} kept going and crashed!", user.pbThis)
        user.applyRecoilDamage(recoilDamage, true, true, recoilMessage)
    end

    def getEffectScore(_user, _target)
        return (@accuracy - 100) * 2
    end
end

#===============================================================================
# If it deals less than 50% of the target’s max health, the user (Capacity Burst)
# takes the difference as recoil.
#===============================================================================
class PokeBattle_Move_197 < PokeBattle_Move
    def pbEffectAfterAllHits(user, target)
        return unless target.damageState.totalCalcedDamage < target.totalhp / 2
        recoilAmount = (target.totalhp / 2) - target.damageState.totalCalcedDamage
        recoilMessage = _INTL("#{user.pbThis} is hurt by leftover electricity!")
        user.applyRecoilDamage(recoilAmount, true, true, recoilMessage)
    end

    def getDamageBasedEffectScore(user,target,damage)
        return 0 if damage >= target.totalhp / 2
        recoilDamage = (target.totalhp / 2) - damage
        score = (-recoilDamage * 2 / user.totalhp).floor
        return score
    end
end

#===============================================================================
# User loses half their current hp in recoil. (Steel Beam, Mist Burst)
#===============================================================================
class PokeBattle_Move_510 < PokeBattle_Move
    def pbEffectAfterAllHits(user, target)
        return if target.damageState.unaffected
        return unless user.takesIndirectDamage?
        @battle.pbDisplay(_INTL("{1} loses half its health in recoil!", user.pbThis))
        user.applyFractionalDamage(1.0 / 2.0, true, true)
    end

    def getEffectScore(user, _target)
        return 0 unless user.takesIndirectDamage?
        return -((user.hp.to_f / user.totalhp.to_f) * 50).floor
    end
end

#===============================================================================
# User loses one third of their current hp in recoil. (Shred Shot, Shards)
#===============================================================================
class PokeBattle_Move_511 < PokeBattle_Move
    def pbEffectAfterAllHits(user, target)
        return if target.damageState.unaffected
        return unless user.takesIndirectDamage?
        @battle.pbDisplay(_INTL("{1} loses one third of its health in recoil!", user.pbThis))
        user.applyFractionalDamage(1.0 / 3.0, true, true)
    end

    def getEffectScore(user, _target)
        return -((user.hp.to_f / user.totalhp.to_f) * 30).floor
    end
end

#===============================================================================
# Damages user by 1/2 of its max HP, even if this move misses. (Mind Blown)
#===============================================================================
class PokeBattle_Move_170 < PokeBattle_Move
    def worksWithNoTargets?; return true; end

    def pbMoveFailed?(user, _targets, show_message)
        unless @battle.moldBreaker
            bearer = @battle.pbCheckGlobalAbility(:DAMP)
            unless bearer.nil?
                if show_message
                    @battle.pbShowAbilitySplash(bearer, :DAMP)
                    @battle.pbDisplay(_INTL("{1} cannot use {2}!", user.pbThis, @name))
                    @battle.pbHideAbilitySplash(bearer)
                end
                return true
            end
        end
        return false
    end

    def shouldShade?(_user, _target)
        return false
    end

    def pbMoveFailedAI?(_user, _targets); return false; end

    def pbSelfKO(user)
        return unless user.takesIndirectDamage?
        user.pbReduceHP((user.totalhp / 2.0).round, false)
        user.pbItemHPHealCheck
    end

    def getEffectScore(user, _target)
        return getHPLossEffectScore(user, 0.5)
    end
end