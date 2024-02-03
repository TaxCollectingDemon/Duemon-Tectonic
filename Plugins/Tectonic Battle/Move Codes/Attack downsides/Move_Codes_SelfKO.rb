#===============================================================================
# User faints, even if the move does nothing else. (Explosion, Self-Destruct)
#===============================================================================
class PokeBattle_Move_UserFaintsExplosive < PokeBattle_Move
    def worksWithNoTargets?; return true; end
    def pbNumHits(_user, _targets, _checkingForAI = false); return 1; end

    def pbMoveFailed?(user, _targets, show_message)
        unless @battle.moldBreaker
            dampHolder = @battle.pbCheckGlobalAbility(:DAMP)
            unless dampHolder.nil?
                if show_message
                    @battle.pbShowAbilitySplash(dampHolder, :DAMP)
                    @battle.pbDisplay(_INTL("{1} cannot use {2}!", user.pbThis, @name))
                    @battle.pbHideAbilitySplash(dampHolder)
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
        return if user.fainted?

        if user.hasActiveAbility?(:SPINESPLODE)
            spikesCount = user.pbOpposingSide.incrementEffect(:Spikes, 2)
            
            if spikesCount > 0
                @battle.pbShowAbilitySplash(user, :SPINESPLODE)
                @battle.pbDisplay(_INTL("#{spikesCount} layers of Spikes were scattered all around #{user.pbOpposingTeam(true)}'s feet!"))
                @battle.pbHideAbilitySplash(user)
            end
        end

        if user.bunkeringDown?
            @battle.pbShowAbilitySplash(user, :BUNKERDOWN)
            @battle.pbDisplay(_INTL("{1}'s {2} barely saves it!", user.pbThis, @name))
            user.pbReduceHP(user.hp - 1, false)
            @battle.pbHideAbilitySplash(user)
        else
            reduction = user.totalhp
            unbreakable = user.hasActiveAbility?(:UNBREAKABLE)
            if unbreakable
                @battle.pbShowAbilitySplash(user, :UNBREAKABLE)
                @battle.pbDisplay(_INTL("{1} resists the recoil!", user.pbThis))
                reduction /= 2
            end
            user.pbReduceHP(reduction, false)
            @battle.pbHideAbilitySplash(user) if unbreakable
            if user.hasActiveAbility?(:PERENNIALPAYLOAD,true)
                @battle.pbShowAbilitySplash(user, :PERENNIALPAYLOAD)
                @battle.pbDisplay(_INTL("{1} will revive in 3 turns!", user.pbThis))
                if user.pbOwnSide.effectActive?(:PerennialPayload)
                    user.pbOwnSide.effects[:PerennialPayload][user.pokemonIndex] = 4
                else
                    user.pbOwnSide.effects[:PerennialPayload] = {
                        user.pokemonIndex => 4,
                    }
                end
                @battle.pbHideAbilitySplash(user)
            end
        end
        user.pbItemHPHealCheck
    end

    def getEffectScore(user, target)
        score = getSelfKOMoveScore(user, target)
        score += 30 if user.bunkeringDown?(true)
        score += 30 if user.hasActiveAbilityAI?(:PERENNIALPAYLOAD)
        if user.hasActiveAbility?(:SPINESPLODE)
            currentSpikeCount = user.pbOpposingSide.countEffect(:Spikes)
            spikesMax = GameData::BattleEffect.get(:Spikes).maximum
            count = [spikesMax, currentSpikeCount + 2].min - currentSpikeCount
            score += count * getHazardSettingEffectScore(user, target)
        end
        return score
    end
end

#===============================================================================
# Inflicts fixed damage equal to user's current HP. (Final Gambit)
# User faints (if successful).
#===============================================================================
class PokeBattle_Move_UserFaintsFixedDamageUserHP < PokeBattle_FixedDamageMove
    def pbNumHits(_user, _targets, _checkingForAI = false); return 1; end

    def pbOnStartUse(user, _targets)
        @finalGambitDamage = user.hp
    end

    def pbFixedDamage(_user, _target)
        return @finalGambitDamage
    end

    def pbBaseDamageAI(_baseDmg, user, _target)
        return user.hp
    end

    def pbSelfKO(user)
        return if user.fainted?
        user.pbReduceHP(user.hp, false)
        user.pbItemHPHealCheck
    end

    def getEffectScore(user, target)
        score = getSelfKOMoveScore(user, target)
        return score
    end
end

#===============================================================================
# User faints, even if the move does nothing else. (Spiky Burst)
# Deals extra damage per "Spike" on the enemy side.
#===============================================================================
class PokeBattle_Move_UserFaintsExplosiveScalesWithEnemySideSpikes < PokeBattle_Move_UserFaintsExplosive
    def pbBaseDamage(baseDmg, _user, target)
        target.pbOwnSide.eachEffect(true) do |effect, value, effectData|
            next unless effectData.is_spike?
            baseDmg += 50 * value
        end
        return baseDmg
    end
end