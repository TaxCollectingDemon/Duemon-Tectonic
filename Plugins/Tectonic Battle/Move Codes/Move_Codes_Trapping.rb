#===============================================================================
# Trapping move. Traps for 3 or 6 rounds. Trapped Pokémon lose 1/16 of max HP
# at end of each round.
#===============================================================================
class PokeBattle_Move_0CF < PokeBattle_Move
    def pbEffectAgainstTarget(user, target)
        return if target.fainted? || target.damageState.substitute
        return if target.effectActive?(:Trapping)
        # Set trapping effect duration and info
        trappingDuration = 3
        trappingDuration *= 2 if user.hasActiveItem?(:GRIPCLAW)
        target.applyEffect(:Trapping, trappingDuration)
        target.applyEffect(:TrappingMove, @id)
        target.pointAt(:TrappingUser, user)
        # Message
        msg = _INTL("{1} was trapped!", target.pbThis)
        case @id
        when :BIND, :VINEBIND, :BEARHUG
            msg = _INTL("{1} was squeezed by {2}!", target.pbThis, user.pbThis(true))
        when :CLAMP, :SLAMSHUT
            msg = _INTL("{1} clamped {2}!", user.pbThis, target.pbThis(true))
        when :FIRESPIN, :CRIMSONSTORM
            msg = _INTL("{1} was trapped in the fiery vortex!", target.pbThis)
        when :INFESTATION,:TERRORSWARM
            msg = _INTL("{1} has been afflicted with an infestation by {2}!", target.pbThis, user.pbThis(true))
        when :MAGMASTORM
            msg = _INTL("{1} became trapped by Magma Storm!", target.pbThis)
        when :SANDTOMB, :SANDVORTEX
            msg = _INTL("{1} became trapped by sand!", target.pbThis)
        when :WHIRLPOOL, :MAELSTROM
            msg = _INTL("{1} became trapped in the vortex!", target.pbThis)
        when :WRAP
            msg = _INTL("{1} was wrapped by {2}!", target.pbThis, user.pbThis(true))
        when :SHATTERVISE
            msg = _INTL("{1} was caught in {2}'s vises!", target.pbThis, user.pbThis(true))
        when :DRAGBENEATH
            msg = _INTL("{1} was dragged beneath the waves!", target.pbThis)
        end
        @battle.pbDisplay(msg)
    end

    def getEffectScore(_user, target)
        return 0 if target.effectActive?(:Trapping) || target.substituted?
        return 40
    end
end

#===============================================================================
# Target can no longer switch out or flee, as long as the user remains active.
# (Anchor Shot, Block, Mean Look, Spider Web, Spirit Shackle, Thousand Waves)
#===============================================================================
class PokeBattle_Move_0EF < PokeBattle_Move
    def pbFailsAgainstTarget?(_user, target, show_message)
        return false if damagingMove?
        if target.effectActive?(:MeanLook)
            if show_message
                @battle.pbDisplay(_INTL("But it failed, since #{target.pbThis(true)} already can't escape!"))
            end
            return true
        end
        return false
    end

    def pbEffectAgainstTarget(user, target)
        return if damagingMove?
        target.pointAt(:MeanLook, user) unless target.effectActive?(:MeanLook)
    end

    def pbAdditionalEffect(user, target)
        return if target.fainted? || target.damageState.substitute
        return if target.effectActive?(:MeanLook)
        target.pointAt(:MeanLook, user) unless target.effectActive?(:MeanLook)
    end

    def getTargetAffectingEffectScore(_user, target)
        return 0 if target.effectActive?(:MeanLook)
        return 50
    end
end

#===============================================================================
# Lowers target's Defense and Special Defense by 1 step at the end of each
# turn. Prevents target from retreating. (Octolock)
#===============================================================================
class PokeBattle_Move_181 < PokeBattle_Move
    def pbFailsAgainstTarget?(_user, target, show_message)
        if target.effectActive?(:Octolock)
            if show_message
                @battle.pbDisplay(_INTL("But it failed, since #{target.pbThis(true)} is already octolocked!"))
            end
            return true
        end
        if target.pbHasType?(:GHOST)
            if show_message
                @battle.pbDisplay(_INTL("But {1} isn't affected because it's a Ghost...",
target.pbThis(true)))
            end
            return true
        end
        return false
    end

    def pbEffectAgainstTarget(user, target)
        target.applyEffect(:Octolock)
        target.pointAt(:OctolockUser, user)
    end

    def getTargetAffectingEffectScore(_user, target)
        score = 60
        score += 60 if target.aboveHalfHealth?
        return score
    end
end

#===============================================================================
# Target can't switch out or flee until they take a hit. (Ice Dungeon)
# Their attacking stats are both lowered by 1 step.
#===============================================================================
class PokeBattle_Move_5F7 < PokeBattle_Move
    def pbFailsAgainstTarget?(user, target, show_message)
        if target.effectActive?(:IceDungeon) && target.pbCanLowerStatStep?(:ATTACK, user, self) &&
                target.pbCanLowerStatStep?(:SPECIAL_ATTACK, user, self)
            if show_message
                @battle.pbDisplay(_INTL("But it failed, since #{target.pbThis(true)} is already imprisoned and its attacking stats can't be reduced!"))
            end
            return true
        end
        return false
    end

    def pbEffectAgainstTarget(user, target)
        target.applyEffect(:IceDungeon)
        target.pbLowerMultipleStatSteps(ATTACKING_STATS_1, user, move: self)
    end

    def getTargetAffectingEffectScore(user, target)
        score = 0
        score += 40 unless target.effectActive?(:IceDungeon)
        score += getMultiStatUpEffectScore(ATTACKING_STATS_1, user, target)
        return score
    end
end

#===============================================================================
# Prevents both the user and the target from escaping. (Jaw Lock)
#===============================================================================
class PokeBattle_Move_17D < PokeBattle_Move
    def pbEffectAgainstTarget(user, target)
        return if target.damageState.substitute
        if !user.effectActive?(:JawLock) && !target.effectActive?(:JawLock)
            user.applyEffect(:JawLock)
            target.applyEffect(:JawLock)
            user.pointAt(:JawLockUser, target)
            target.pointAt(:JawLockUser, user)
            @battle.pbDisplay(_INTL("Neither Pokémon can escape!"))
        end
    end

    def getTargetAffectingEffectScore(_user, target)
        return 20 unless target.effectActive?(:JawLock)
        return 0
    end
end

#===============================================================================
# Traps the target and frostbites them. (Icicle Pin)
#===============================================================================
class PokeBattle_Move_11A < PokeBattle_Move_0EF
    def pbFailsAgainstTarget?(user, target, show_message)
        return false if damagingMove?
        if target.effectActive?(:MeanLook) && !target.canFrostbite?(user, false, self)
            if show_message
                @battle.pbDisplay(_INTL("But it failed, since #{target.pbThis(true)} is already trapped and can't be frostbitten!"))
            end
            return true
        end
        return false
    end

    def pbEffectAgainstTarget(user, target)
        super
        target.applyFrostbite(user) if target.canFrostbite?(user, false)
    end

    def getTargetAffectingEffectScore(user, target)
        score = 0
        score += 50 unless target.effectActive?(:MeanLook)
        score += getFrostbiteEffectScore(user, target)
        return score
    end
end

#===============================================================================
# No Pokémon can switch out or flee until the end of the next round. (Fairy Lock)
#===============================================================================
class PokeBattle_Move_152 < PokeBattle_Move
    def pbMoveFailed?(_user, _targets, show_message)
        if @battle.field.effectActive?(:FairyLock)
            @battle.pbDisplay(_INTL("But it failed, since a Fairy Lock is already active!")) if show_message
            return true
        end
        return false
    end

    def pbEffectGeneral(_user)
        @battle.field.applyEffect(:FairyLock, 2)
        @battle.pbDisplay(_INTL("No one will be able to run away during the next turn!"))
    end

    def getEffectScore(_user, _target)
        echoln("The AI will never use Fairy Lock.")
        return 0 # The move is both annoying and very weak
    end
end