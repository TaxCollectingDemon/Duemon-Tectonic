#===============================================================================
# Transfers the user's status to the target (Vicious Cleaning)
#===============================================================================
class PokeBattle_Move_580 < PokeBattle_Move
    def pbEffectAgainstTarget(user, target)
        user.getStatuses.each do |status|
            next if status == :NONE
            if target.pbCanInflictStatus?(status, user, false, self)
                case status
                when :SLEEP
                    target.applySleep
                when :POISON
                    target.applyPoison(user, nil, user.statusCount != 0)
                when :BURN
                    target.applyBurn(user)
                when :NUMB
                    target.applyNumb(user)
                when :FROSTBITE
                    target.applyFrostbite(user)
                when :DIZZY
                    target.applyDizzy(user)
                when :LEECHED
                    target.applyLeeched(user)
                end
            else
                statusData = GameData::Status.get(status)
                @battle.pbDisplay(_INTL("{1} tries to transfer its {2} to {3}, but...", user.pbThis, statusData.name,
target.pbThis(true)))
                target.pbCanInflictStatus?(status, user, true, self)
            end
            user.pbCureStatus(status)
        end
    end

    def shouldHighlight?(user, _target)
        return user.pbHasAnyStatus?
    end
end

#===============================================================================
# Restores health by 50% and raises Speed by one step. (Mulch Meal)
#===============================================================================
class PokeBattle_Move_583 < PokeBattle_HalfHealingMove
    def pbMoveFailed?(user, _targets, show_message)
        if !user.canHeal? && !user.pbCanRaiseStatStep?(:SPEED, user, self, true)
            @battle.pbDisplay(_INTL("But it failed, since #{user.pbThis(true)} can't heal or raise its Speed!")) if show_message
            return true
        end
    end

    def pbEffectGeneral(user)
        super
        user.tryRaiseStat(:SPEED, user, move: self)
    end

    def getEffectScore(user, target)
        score = super
        score += 20
        score -= user.steps[:SPEED] * 20
        return score
    end
end

#===============================================================================
# Raises the target's worst three stats by one step each. (Guiding Aroma)
#===============================================================================
class PokeBattle_Move_584 < PokeBattle_Move
    def pbFailsAgainstTarget?(user, target, show_message)
        if statUp(user, target).length == 0
            @battle.pbDisplay(_INTL("{1}'s stats won't go any higher!", target.pbThis)) if show_message
            return true
        end
        return false
    end

    def statUp(user, target)
        statsTargetCanRaise = target.finalStats.select do |stat, _finalValue|
            next target.pbCanRaiseStatStep?(stat, user, self)
        end
        statsRanked = statsTargetCanRaise.sort_by { |_s, v| v }.to_h.keys
        statUp = []
        statsRanked.each_with_index do |stat, index|
            break if index > 2
            statUp.push(stat)
            statUp.push(1)
        end
        return statUp
    end

    def pbEffectAgainstTarget(user, target)
        target.pbRaiseMultipleStatSteps(statUp(user, target), user, move: self)
    end

    def getEffectScore(user, target)
        return 0 if statUp(user, target).length == 0
        return getMultiStatUpEffectScore(statUp(user, target), user, target)
    end
end

#===============================================================================
# Resets all stat steps at end of turn and at the end of the next four turns. (Grey Mist)
#===============================================================================
class PokeBattle_Move_587 < PokeBattle_Move
    def pbEffectGeneral(_user)
        @battle.field.applyEffect(:GreyMist, 5) unless @battle.field.effectActive?(:GreyMist)
    end

    def pbMoveFailed?(_user, _targets, show_message)
        return false if damagingMove?
        if @battle.field.effectActive?(:GreyMist)
            if show_message
                @battle.pbDisplay(_INTL("But it failed, since the field is already shrouded in Grey Mist!"))
            end
            return true
        end
        return false
    end

    def getEffectScore(user, _target)
        return getGreyMistSettingEffectScore(user,5)
    end
end

#===============================================================================
# Counts as a use of Rock Roll, Snowball, or Furycutter. (On A Roll)
#===============================================================================
class PokeBattle_Move_58B < PokeBattle_Move
    def pbChangeUsageCounters(user, specialUsage)
        oldEffectValues = {}
        user.eachEffect(true) do |effect, value, data|
            oldEffectValues[effect] = value if data.snowballing_move_counter?
        end
        super
        oldEffectValues.each do |effect, oldValue|
            data = GameData::BattleEffect.get(effect)
            user.effects[effect] = [oldValue + 1, data.maximum].min
        end
    end
end

#===============================================================================
# The user's Speed raises 4 steps, and it gains the Flying-type. (Mach Flight)
#===============================================================================
class PokeBattle_Move_58C < PokeBattle_Move_030
    def pbMoveFailed?(user, targets, show_message)
        return false if GameData::Type.exists?(:FLYING) && !user.pbHasType?(:FLYING) && user.canChangeType?
        super
    end

    def pbEffectGeneral(user)
        super
        user.applyEffect(:Type3, :FLYING)
    end
end

#===============================================================================
# Guaranteed to crit, but lowers the user's speed. (Incision)
#===============================================================================
class PokeBattle_Move_58D < PokeBattle_Move_03E
    def pbCriticalOverride(_user, _target); return 1; end
end

#===============================================================================
# Faints the opponant if they are below 1/4 HP, after dealing damage. (Cull)
#===============================================================================
class PokeBattle_Move_58F < PokeBattle_Move
    def canCull?(target)
        return target.hp < (target.totalhp / 4)
    end

    def pbEffectAgainstTarget(user, target)
        if canCull?(target)
            @battle.pbDisplay(_INTL("#{user.pbThis} culls #{target.pbThis(true)}!"))
            target.pbReduceHP(target.hp, false)
            target.pbItemHPHealCheck
        end
    end

    def shouldHighlight?(_user, target)
        return canCull?(target)
    end
end

#===============================================================================
# The user, if a Deerling or Sawsbuck, changes their form in season order. (Season's End)
#===============================================================================
class PokeBattle_Move_590 < PokeBattle_Move
    def pbMoveFailed?(user, _targets, show_message)
        unless user.countsAs?(:DEERLING) || user.countsAs?(:SAWSBUCK)
            @battle.pbDisplay(_INTL("But {1} can't use the move!", user.pbThis)) if show_message
            return true
        end
        return false
    end

    def pbEffectGeneral(user)
        if user.countsAs?(:DEERLING) || user.countsAs?(:SAWSBUCK)
            newForm = (user.form + 1) % 4
            formChangeMessage = _INTL("The season shifts!")
            user.pbChangeForm(newForm, formChangeMessage)
        end
    end
end

#===============================================================================
# Power increases the taller the user is than the target. (Cocodrop)
#===============================================================================
class PokeBattle_Move_591 < PokeBattle_Move
    def pbBaseDamage(_baseDmg, user, target)
        ret = 40
        ratio = user.pbHeight.to_f / target.pbHeight.to_f
        ratio = 10 if ratio > 10
        ret += ((16 * (ratio**0.75)) / 5).floor * 5
        return ret
    end
end

#===============================================================================
# Does Dragon-Darts style hit redirection, plus
# each target hit loses 1 step of Speed. (Tar Volley)
#===============================================================================
class PokeBattle_Move_592 < PokeBattle_Move_17C
    def pbAdditionalEffect(user, target)
        return if target.damageState.substitute
        target.tryLowerStat(:SPEED, user, move: self)
    end
end

#===============================================================================
# Power doubles if has the Defense Curl effect, which it consumes. (Rough & Tumble)
#===============================================================================
class PokeBattle_Move_594 < PokeBattle_Move
    def pbBaseDamage(baseDmg, user, _target)
        baseDmg *= 2 if user.effectActive?(:DefenseCurl)
        return baseDmg
    end

    def pbEffectAfterAllHits(user, _target)
        user.disableEffect(:DefenseCurl)
    end
end

#===============================================================================
# User's Attack and Defense are raised by one step each, and changes user's type to Rock. (Built Different)
#===============================================================================
class PokeBattle_Move_595 < PokeBattle_Move_024
    def pbMoveFailed?(user, targets, show_message)
        return false if GameData::Type.exists?(:ROCK) && !user.pbHasType?(:ROCK) && user.canChangeType?
        super
    end

    def pbEffectGeneral(user)
        super
        user.applyEffect(:Type3, :ROCK)
    end
end

#===============================================================================
# The target cannot escape and takes 50% more damage from all attacks. (Death Mark)
#===============================================================================
class PokeBattle_Move_596 < PokeBattle_Move
    def pbFailsAgainstTarget?(user, target, show_message)
        if target.effectActive?(:DeathMark)
            @battle.pbDisplay(_INTL("But it failed, since the target is already marked for death!")) if show_message
            return true
        end
        return false
    end

    def pbEffectAgainstTarget(user, target)
        target.pointAt(:DeathMark, user) unless target.effectActive?(:DeathMark)
    end
end

#===============================================================================
# The user picks between moves to use, those being the 3 last moves used by any foe. (Cross Examine)
#===============================================================================
class PokeBattle_Move_598 < PokeBattle_Move
    def resolutionChoice(user)
        @chosenMoveID = :STRUGGLE
        validMoves = validMoveArray(user)
        moveChoices = []
        validMoves.reverse.each do |moveID|
            next if moveChoices.include?(moveID)
            moveChoices.push(moveID)
            break if moveChoices.length == 3
        end

        moveNames = []
        moveChoices.each do |moveID|
            moveNames.push(GameData::Move.get(moveID).name)
        end
        if moveChoices.length == 1
            @chosenMoveID = moveChoices[0]
        elsif moveChoices.length > 1
            if @battle.autoTesting
                @chosenMoveID = moveChoices.sample
            elsif !user.pbOwnedByPlayer? # Trainer AI
                @chosenMoveID = moveChoices[0]
            else
                chosenIndex = @battle.scene.pbShowCommands(_INTL("Which move should #{user.pbThis(true)} use?"),moveNames,0)
                @chosenMoveID = moveChoices[chosenIndex]
            end
        end
    end

    def validMoveArray(user)
        if user.opposes?
            return @battle.allMovesUsedSide0
        else
            return @battle.allMovesUsedSide1
        end
    end

    def pbMoveFailed?(user, targets, show_message)
        if validMoveArray(user).empty?
            @battle.pbDisplay(_INTL("But it failed, since no foe has yet used a move!")) if show_message
            return true
        end
        super
    end

    def pbEffectGeneral(user)
        user.pbUseMoveSimple( @chosenMoveID)
    end

    def resetMoveUsageState
        @chosenMoveID = nil
    end

    def getEffectScore(_user, _target)
        echoln("The AI will never use Cross-Examine.")
        return 0
    end
end

#===============================================================================
# Decreases the user's Sp. Def.
# Increases the user's Sp. Atk by 1 step, and Speed by 2 steps.
# (Shed Coat)
#===============================================================================
class PokeBattle_Move_5A2 < PokeBattle_StatUpDownMove
    def initialize(battle, move)
        super
        @statUp   = [:SPEED, 3, :SPECIAL_ATTACK, 3]
        @statDown = [:SPECIAL_DEFENSE, 2]
    end
end

#===============================================================================
# Reduce's the target's highest attacking stat. (Scale Glint)
#===============================================================================
class PokeBattle_Move_5AA < PokeBattle_Move
    def pbAdditionalEffect(user, target)
        return if target.damageState.substitute
        if target.pbAttack > target.pbSpAtk
            target.pbLowerMultipleStatSteps([:ATTACK,1], user, move: self)
        else
            target.pbLowerMultipleStatSteps([:SPECIAL_ATTACK,1], user, move: self)
        end
    end

    def getTargetAffectingEffectScore(user, target)
        if target.pbAttack > target.pbSpAtk
            statDownArray = [:ATTACK,1]
        else
            statDownArray = [:SPECIAL_ATTACK,1]
        end
        return getMultiStatDownEffectScore(statDownArray, user, target)
    end
end

#===============================================================================
# User heals itself based on current weight. (Refurbish)
# Then, its current weigtht is cut in half.
#===============================================================================
class PokeBattle_Move_5AB < PokeBattle_HealingMove
    def healRatio(user)
        case user.pbWeight
        when 1024..999_999
            return 1.0
        when 512..1023
            return 0.75
        when 256..511
            return 0.5
        when 128..255
            return 0.25
        when 64..127
            return 0.125
        else
            return 0.0625
        end
    end

    def pbEffectGeneral(user)
        super
        user.incrementEffect(:Refurbished)
    end
end

#===============================================================================
# Leeches or numbs the target, depending on how its speed compares to the user.
# (Mystery Seed)
#===============================================================================
class PokeBattle_Move_5AC < PokeBattle_Move
    def pbFailsAgainstTarget?(user, target, show_message)
        return false if damagingMove?
        if !target.canLeech?(user, show_message, self) && !target.canNumb?(user, show_message, self)
            if show_message
                @battle.pbDisplay(_INTL("But it failed, since #{target.pbThis(true)} can neither be leeched or numbed!"))
            end
            return true
        end
        return false
    end

    def pbEffectAgainstTarget(user, target)
        return if damagingMove?
        leechOrNumb(user, target)
    end

    def pbAdditionalEffect(user, target)
        return if target.damageState.substitute
        leechOrNumb(user, target)
    end

    def leechOrNumb(user, target)
        target_speed = target.pbSpeed
        user_speed = user.pbSpeed

        if target.canNumb?(user, false, self) && target_speed >= user_speed
            target.applyNumb(user)
        elsif target.canLeech?(user, false, self) && user_speed >= target_speed
            target.applyLeeched(user)
        end
    end

    def getTargetAffectingEffectScore(user, target)
        target_speed = target.pbSpeed
        user_speed = user.pbSpeed

        if target.canNumb?(user, false, self) && target_speed >= user_speed
            return getNumbEffectScore(user, target)
        elsif target.canLeech?(user, false, self) && user_speed >= target_speed
            return getLeechEffectScore(user, target)
        end
        return 0
    end
end

#===============================================================================
# Target becomes trapped. Summons Eclipse for 8 turns.
# (Captivating Sight)
#===============================================================================
class PokeBattle_Move_5AF < PokeBattle_Move_0EF
    def pbFailsAgainstTarget?(_user, target, show_message)
        return false unless @battle.primevalWeatherPresent?(false)
        super
    end

    def pbEffectGeneral(user)
        @battle.pbStartWeather(user, :Eclipse, 8, false) unless @battle.primevalWeatherPresent?
    end

    def getEffectScore(user, _target)
        score = super
        score += getWeatherSettingEffectScore(:Eclipse, user, @battle, 8)
        return score
    end
end

#===============================================================================
# Summons Moonglow for 8 turns. Raises the Attack of itself and all allies by 2 steps. (Midnight Hunt)
#===============================================================================
class PokeBattle_Move_5B0 < PokeBattle_Move_530
    def pbMoveFailed?(user, _targets, show_message)
        return false unless @battle.primevalWeatherPresent?(false)
        super
    end

    def pbEffectGeneral(user)
        @battle.pbStartWeather(user, :Moonglow, 8, false) unless @battle.primevalWeatherPresent?
        super
    end

    def getEffectScore(user, _target)
        score = super
        score += getWeatherSettingEffectScore(:Moonglow, user, @battle, 8)
        return score
    end
end

#===============================================================================
# Target is frostbitten if in moonglow. (Night Chill)
#===============================================================================
class PokeBattle_Move_5B1 < PokeBattle_FrostbiteMove
    def pbAdditionalEffect(user, target)
        return unless @battle.moonGlowing?
        super
    end

    def getTargetAffectingEffectScore(user, target)
        return 0 unless @battle.moonGlowing?
        super
    end
end

#===============================================================================
# Target is burned if in eclipse. (Calamitous Slash)
#===============================================================================
class PokeBattle_Move_5B2 < PokeBattle_BurnMove
    def pbAdditionalEffect(user, target)
        return unless @battle.eclipsed?
        super
    end

    def getTargetAffectingEffectScore(user, target)
        return 0 unless @battle.eclipsed?
        super
    end
end

#===============================================================================
# Sets stealth rock and sandstorm for 5 turns. (Stone Signal)
#===============================================================================
class PokeBattle_Move_5BD < PokeBattle_Move_105
    def pbMoveFailed?(user, _targets, show_message)
        return false
    end

    def pbEffectGeneral(user)
        super
        @battle.pbStartWeather(user, :Sandstorm, 5, false) unless @battle.primevalWeatherPresent?
    end
end

#===============================================================================
# Minimizes the target's Speed and Evasiveness. (Freeze Ray)
#===============================================================================
class PokeBattle_Move_5C0 < PokeBattle_Move
    def pbAdditionalEffect(user, target)
        return if target.damageState.substitute
        target.pbMinimizeStatStep(:SPEED, user, self)
        target.pbMinimizeStatStep(:EVASION, user, self)
    end

    def getTargetAffectingEffectScore(user, target)
        return getMultiStatDownEffectScore([:SPEED,4,:EVASION,4], user, target)
    end
end

#===============================================================================
# Changes Category based on which will deal more damage. (Everhone)
# Raises the stat that wasn't selected to be used.
#===============================================================================
class PokeBattle_Move_5C1 < PokeBattle_Move
    def initialize(battle, move)
        super
        @calculated_category = 1
    end

    def calculateCategory(user, targets)
        return selectBestCategory(user, targets[0])
    end

    def pbAdditionalEffect(user, _target)
        if @calculated_category == 0
            return user.tryRaiseStat(:SPECIAL_ATTACK, user, increment: 1, move: self)
        else
            return user.tryRaiseStat(:ATTACK, user, increment: 1, move: self)
        end
    end

    def getEffectScore(user, target)
        expectedCategory = selectBestCategory(user, target)
        if expectedCategory == 0
            return getMultiStatUpEffectScore([:SPECIAL_ATTACK, 1], user, user)
        else
            return getMultiStatUpEffectScore([:ATTACK, 1], user, user)
        end
    end
end

#===============================================================================
# Heals user by 1/2, raises Defense, Sp. Defense, Crit Chance. (Divination)
#===============================================================================
class PokeBattle_Move_5C7 < PokeBattle_HalfHealingMove
    def pbMoveFailed?(user, _targets, show_message)
        if user.effectAtMax?(:FocusEnergy) && !user.pbCanRaiseStatStep?(:DEFENSE, user, self) && 
                !user.pbCanRaiseStatStep?(:SPECIAL_DEFENSE, user, self)
            return super
        end
        return false
    end

    def pbEffectGeneral(user)
        super
        user.pbRaiseMultipleStatSteps(DEFENDING_STATS_2, user, move: self)
        user.incrementEffect(:FocusEnergy, 2) unless user.effectAtMax?(:FocusEnergy)
    end

    def getEffectScore(user, target)
        score = super
        score += getMultiStatUpEffectScore(DEFENDING_STATS_2, user, target)
        score += getCriticalRateBuffEffectScore(user, 2)
        return score
    end
end

#===============================================================================
# Damages target if target is a foe, or buff's the target's Speed
# by four steps if it's an ally. (Lightning Spear)
#===============================================================================
class PokeBattle_Move_5C8 < PokeBattle_Move
    def pbOnStartUse(user, targets)
        @buffing = false
        @buffing = !user.opposes?(targets[0]) if targets.length > 0
    end

    def pbFailsAgainstTarget?(user, target, show_message)
        return false unless @buffing
        return !target.pbCanRaiseStatStep?(:SPEED, user, self, true)
    end

    def damagingMove?(aiCheck = false)
        if aiCheck
            return super
        else
            return false if @buffing
            return super
        end
    end

    def pbEffectAgainstTarget(user, target)
        return unless @buffing
        target.pbRaiseMultipleStatSteps([:SPEED, 4], user, move: self)
    end

    def pbShowAnimation(id, user, targets, hitNum = 0, showAnimation = true)
        if @buffing
            @battle.pbAnimation(:CHARGE, user, targets, hitNum) if showAnimation
        else
            super
        end
    end
end

#===============================================================================
# The user puts all their effort into attacking their opponent
# causing them to rest on their next turn. (Extreme Effort)
#===============================================================================
class PokeBattle_Move_5C9 < PokeBattle_Move
    def pbEffectGeneral(user)
	    user.applyEffect(:ExtremeEffort, 2)
    end

    def getEffectScore(user, _target)
        return -getSleepEffectScore(nil, user) / 2
    end
end

#===============================================================================
# Type changes depending on rotom's form. (Machinate)
# Additional effect changes depending on rotom's form. Only usable by rotom.
#===============================================================================
class PokeBattle_Move_5CB < PokeBattle_Move
    def aiAutoKnows?(pokemon); return true; end
    def pbMoveFailed?(user, _targets, show_message)
        unless user.countsAs?(:ROTOM)
            @battle.pbDisplay(_INTL("But {1} can't use the move!", user.pbThis(true))) if show_message
            return true
        end
        return false
    end

    def pbBaseType(user)
        ret = :GHOST
        case user.form
        when 1
            ret = :FIRE if GameData::Type.exists?(:FIRE)
        when 2
            ret = :WATER if GameData::Type.exists?(:WATER)
        when 3
            ret = :ICE if GameData::Type.exists?(:ICE)
        when 4
            ret = :FLYING if GameData::Type.exists?(:FLYING)
        when 5
            ret = :GRASS if GameData::Type.exists?(:GRASS)
        end
        return ret
    end

    def pbAdditionalEffect(user, target)
        return if target.damageState.substitute
        case user.form
        when 1
            target.applyBurn(user) if target.canBurn?(user, true, self)
        when 2
            target.applyNumb(user) if target.canNumb?(user, true, self)
        when 3
            target.applyFrostbite(user) if target.canFrostbite?(user, true, self)
        when 4
            target.applyDizzy(user) if target.canDizzy?(user, true, self)
        when 5
            target.applyLeeched(user) if target.canLeech?(user, true, self)
        end
    end

    def getTargetAffectingEffectScore(user, target)
        case user.form
        when 1
            return getBurnEffectScore(user, target)
        when 2
            return getNumbEffectScore(user, target)
        when 3
            return getFrostbiteEffectScore(user, target)
        when 4
            return getDizzyEffectScore(user, target)
        when 5
            return getLeechEffectScore(user, target)
        end
        return 0
    end
end

#===============================================================================
# In wild battles, makes target flee. Fails if target is a higher level than the
# user.
# In trainer battles, target switches out, to be replaced manually. (Dragon's Roar)
#===============================================================================
class PokeBattle_Move_5CC < PokeBattle_Move
    def forceSwitchMove?; return true; end

    def pbEffectAgainstTarget(user, target)
        if @battle.wildBattle? && target.level <= user.level && @battle.canRun &&
           (target.substituted? || ignoresSubstitute?(user)) && !target.boss
            @battle.decision = 3
        end
    end

    def pbSwitchOutTargetsEffect(user, targets, numHits, switchedBattlers)
        return if numHits == 0
        forceOutTargets(user, targets, switchedBattlers, substituteBlocks: false)
    end

    def getTargetAffectingEffectScore(user, target)
        return getForceOutEffectScore(user, target, false)
    end
end

#===============================================================================
# Power doubles if the target is the last alive on their team.
# (Checkmate)
#===============================================================================
class PokeBattle_Move_5CD < PokeBattle_Move
    def pbBaseDamage(baseDmg, _user, target)
        baseDmg *= 2 if target.isLastAlive?
        return baseDmg
    end
end

#===============================================================================
# For 5 rounds, disables the last move the target used. Also, remove 5 PP from it. (Gem Seal)
#===============================================================================
class PokeBattle_Move_5CF < PokeBattle_Move_0B9
    def pbEffectAgainstTarget(_user, target)
        super
        target.eachMove do |m|
            next if m.id != target.lastRegularMoveUsed
            reduction = [5, m.pp].min
            target.pbSetPP(m, m.pp - reduction)
            @battle.pbDisplay(_INTL("It reduced the PP of {1}'s {2} by {3}!",
               target.pbThis(true), m.name, reduction))
            break
        end
    end

    def getEffectScore(_user, target)
        score = super
        score += 10
        return score
    end
end

#===============================================================================
# Restores health by half and gains an Aqua Ring. (River Rest)
#===============================================================================
class PokeBattle_Move_5D0 < PokeBattle_HalfHealingMove
    def pbMoveFailed?(user, _targets, show_message)
        if super(user, _targets, false) && user.effectActive?(:AquaRing)
            @battle.pbDisplay(_INTL("But it failed, since #{user.pbThis} can't heal and already has a veil of water!")) if show_message
            return true
        end
        return false
    end

    def pbEffectGeneral(user)
        super
        user.applyEffect(:AquaRing)
    end

    def getEffectScore(user, target)
        score = super
        score += getAquaRingEffectScore(user)
        return score
    end
end

#===============================================================================
# Increases Speed by 4 steps and Crit Chance by 2 steps. (Deep Breathing)
#===============================================================================
class PokeBattle_Move_5D2 < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:SPEED, 4]
    end

    def pbMoveFailed?(user, _targets, show_message)
        if user.effectAtMax?(:FocusEnergy)
            return super
        end
        return false
    end

    def pbEffectGeneral(user)
        super
        user.incrementEffect(:FocusEnergy, 2)
    end

    def getEffectScore(user, _target)
        score = super
        score += getCriticalRateBuffEffectScore(user, 2)
        return score
    end
end

#===============================================================================
# For 6 rounds, doubles the Speed of all battlers on the user's side. (Sustained Wind)
#===============================================================================
class PokeBattle_Move_5D3 < PokeBattle_Move_05B
    def initialize(battle, move)
        super
        @tailwindDuration = 6
    end
end

#===============================================================================
# Heals user by 1/2 of their HP.
# Extends the duration of any screens affecting the user's side by 1. (Stabilize)
#===============================================================================
class PokeBattle_Move_5D4 < PokeBattle_HalfHealingMove
    def pbEffectGeneral(user)
        super
        pbOwnSide.eachEffect(true) do |effect, value, data|
            next unless data.is_screen?
            pbOwnSide.effects[effect] += 1
            @battle.pbDisplay(_INTL("{1}'s {2} was extended 1 turn!", pbTeam, data.name))
        end
    end

    def getEffectScore(user, target)
        score = super
        pbOwnSide.eachEffect(true) do |effect, value, data|
            next unless data.is_screen?
            score += 30
        end
        return score
    end
end

#===============================================================================
# User heals for 3/5ths of their HP. (Heal Order)
#===============================================================================
class PokeBattle_Move_5D6 < PokeBattle_HealingMove
    def healRatio(_user)
        return 3.0 / 5.0
    end
end

#===============================================================================
# Target becomes your choice of Dragon, Fairy, or Steel type. (Regalia)
#===============================================================================
class PokeBattle_Move_5D7 < PokeBattle_Move
    def resolutionChoice(user)
        validTypes = %i[DRAGON FAIRY STEEL]
        validTypeNames = []
        validTypes.each do |typeID|
            validTypeNames.push(GameData::Type.get(typeID).name)
        end
        if validTypes.length == 1
            @chosenType = validTypes[0]
        elsif validTypes.length > 1
            if @battle.autoTesting
                @chosenType = validTypes.sample
            elsif !user.pbOwnedByPlayer? # Trainer AI
                @chosenType = validTypes[0]
            else
                chosenIndex = @battle.scene.pbShowCommands(_INTL("Which type should #{user.pbThis(true)} gift?"),validTypeNames,0)
                @chosenType = validTypes[chosenIndex]
            end
        end
    end

    def pbFailsAgainstTarget?(_user, target, show_message)
        unless GameData::Type.exists?(@chosenType)
            @battle.pbDisplay(_INTL("But it failed, since the chosen type doesn't exist!")) if show_message
            return true
        end
        unless target.canChangeType?
            @battle.pbDisplay(_INTL("But it failed, since #{target.pbThis(true)} can't change their type!")) if show_message
            return true
        end
        unless target.pbHasOtherType?(@chosenType)
            @battle.pbDisplay(_INTL("But it failed, since #{target.pbThis(true)} is already only the chosen type!")) if show_message
            return true
        end
        return false
    end

    def pbFailsAgainstTargetAI?(_user, target)
        @chosenType = :DRAGON
        return pbFailsAgainstTarget?(_user, target, false)
    end

    def pbEffectAgainstTarget(_user, target)
        target.pbChangeTypes(@chosenType)
        typeName = GameData::Type.get(@chosenType).name
        @battle.pbDisplay(_INTL("{1} transformed into the {2} type!", target.pbThis, typeName))
    end

    def resetMoveUsageState
        @chosenType = nil
    end

    def getEffectScore(_user, _target)
        return 80
    end
end

#===============================================================================
# Target moves immediately after the user and deals 50% more damage. (Amp Up)
#===============================================================================
class PokeBattle_Move_5F4 < PokeBattle_Move_09C
    def pbEffectAgainstTarget(_user, target)
        super
        target.applyEffect(:MoveNext)
        @battle.pbDisplay(_INTL("{1} is amped up!", target.pbThis))
    end

    def pbFailsAgainstTargetAI?(_user, _target); return false; end

    def getEffectScore(user, target)
        score = super
        score += 50 if @battle.battleAI.userMovesFirst?(self, user, target)
        return score
    end
end

#===============================================================================
# User takes recoil damage equal to 1/3 of the damage this move dealt. (Undying Rush)
# But can't faint from that recoil damage.
#===============================================================================
class PokeBattle_Move_5F6 < PokeBattle_RecoilMove
    def recoilFactor;  return (1.0 / 3.0); end
    
    def pbRecoilDamage(user, target)
        damage = (target.damageState.totalHPLost * finalRecoilFactor(user)).round
        damage = [damage,(user.hp - 1)].min
        return damage
    end

    def pbEffectAfterAllHits(user, target)
        return if target.damageState.unaffected
        recoilDamage = pbRecoilDamage(user, target)
        return if recoilDamage <= 0
        user.applyRecoilDamage(recoilDamage, false, true)
    end
end

#===============================================================================
# Target's Defense is lowered by 3 steps if in sandstorm. (Grindstone)
#===============================================================================
class PokeBattle_Move_5F8 < PokeBattle_TargetStatDownMove
    def initialize(battle, move)
        super
        @statDown = [:DEFENSE, 3]
    end

    def pbAdditionalEffect(user, target)
        return if target.damageState.substitute
        return unless @battle.sandy?
        target.tryLowerStat(@statDown[0], user, increment: @statDown[1], move: self)
    end

    def getTargetAffectingEffectScore(user, target)
        return 0 unless @battle.sandy?
        return getMultiStatDownEffectScore(@statDown, user, target)
    end

    def shouldHighlight?(_user, _target)
        return @battle.sandy?
    end
end

#===============================================================================
# Multi-hit move that can dizzy.
#===============================================================================
class PokeBattle_Move_5FC < PokeBattle_DizzyMove
    include RandomHitable
end

#===============================================================================
# For 4 rounds, disables the last move the target used. (Drown)
# Then debuffs a stat based on what was disabled.
#===============================================================================
class PokeBattle_Move_5FD < PokeBattle_Move_0B9
    def initialize(battle, move)
        super
        @disableTurns = 4
    end

    def pbEffectAgainstTarget(user, target)
        super
        statToLower = getDebuffingStat(target)
        target.pbLowerStatStep(statToLower, 4, user) if target.pbCanLowerStatStep?(statToLower,user,self,true)
    end

    def getDebuffingStat(battler)
        return :SPEED unless battler.lastRegularMoveUsed
        case GameData::Move.get(battler.lastRegularMoveUsed).category
        when 0
            return :ATTACK
        when 1
            return :SPECIAL_ATTACK
        when 2
            return :SPEED
        end
    end

    def getEffectScore(user, target)
        score = super
        score += getMultiStatDownEffectScore([getDebuffingStat(target),4],user,target)
        return score
    end
end

#===============================================================================
# Two turn attack. Attacks first turn, skips second turn (if successful).
# The second-turn skipping it removed if the target fains or switches out.
#===============================================================================
class PokeBattle_Move_5FE < PokeBattle_Move_0C2
    def initialize(battle, move)
        super
        @exhaustionTracker = :Attached
    end

    def pbEffectAfterAllHits(user, target)
        return if target.damageState.fainted
        super
        user.pointAt(:AttachedTo, target)
    end
end