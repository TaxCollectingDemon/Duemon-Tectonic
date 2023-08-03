ItemHandlers::UseOnPokemon.add(:POTION,proc { |item,pkmn,scene|
    next pbHPItem(pkmn,40,scene)
  })
  
  ItemHandlers::UseOnPokemon.copy(:POTION,:BERRYJUICE,:SWEETHEART)
  ItemHandlers::UseOnPokemon.copy(:POTION,:RAGECANDYBAR) if !Settings::RAGE_CANDY_BAR_CURES_STATUS_PROBLEMS
  
  ItemHandlers::UseOnPokemon.add(:SUPERPOTION,proc { |item,pkmn,scene|
    next pbHPItem(pkmn,80,scene)
  })
  
  ItemHandlers::UseOnPokemon.add(:HYPERPOTION,proc { |item,pkmn,scene|
    next pbHPItem(pkmn,120,scene)
  })
  
  ItemHandlers::UseOnPokemon.add(:MAXPOTION,proc { |item,pkmn,scene|
    next pbHPItem(pkmn,pkmn.totalhp-pkmn.hp,scene)
  })
  
  ItemHandlers::UseOnPokemon.add(:FRESHWATER,proc { |item,pkmn,scene|
    next pbHPItem(pkmn,50,scene)
  })
  
  ItemHandlers::UseOnPokemon.add(:SODAPOP,proc { |item,pkmn,scene|
    next pbHPItem(pkmn,60,scene)
  })
  
  ItemHandlers::UseOnPokemon.add(:LEMONADE,proc { |item,pkmn,scene|
    next pbHPItem(pkmn,80,scene)
  })
  
  ItemHandlers::UseOnPokemon.add(:MOOMOOMILK,proc { |item,pkmn,scene|
    next pbHPItem(pkmn,100,scene)
  })

  
  ItemHandlers::UseOnPokemon.add(:FULLHEAL,proc { |item,pkmn,scene|
    if pkmn.fainted? || pkmn.status == :NONE
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    end
    pkmn.heal_status
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} became healthy.",pkmn.name))
    next true
  })

  ItemHandlers::UseOnPokemon.copy(:FULLHEAL)
  
  ItemHandlers::UseOnPokemon.copy(:FULLHEAL,
     :LAVACOOKIE,:OLDGATEAU,:CASTELIACONE,:LUMIOSEGALETTE,:SHALOURSABLE,
     :BIGMALASADA,:RAGECANDYBAR,:STATUSHEAL)
  
  ItemHandlers::UseOnPokemon.add(:FULLRESTORE,proc { |item,pkmn,scene|
    if pkmn.fainted? || (pkmn.hp==pkmn.totalhp && pkmn.status == :NONE)
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    end
    hpgain = pbItemRestoreHP(pkmn,pkmn.totalhp-pkmn.hp)
    pkmn.heal_status
    scene.pbRefresh
    if hpgain>0
      scene.pbDisplay(_INTL("{1}'s HP was restored by {2} points.",pkmn.name,hpgain))
    else
      scene.pbDisplay(_INTL("{1} became healthy.",pkmn.name))
    end
    next true
  })
  
  ItemHandlers::UseOnPokemon.add(:REVIVE,proc { |item,pkmn,scene|
    if !pkmn.fainted?
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    end
    pkmn.hp = (pkmn.totalhp/2).floor
    pkmn.hp = 1 if pkmn.hp<=0
    pkmn.heal_status
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s HP was restored.",pkmn.name))
    next true
  })
  
  ItemHandlers::UseOnPokemon.add(:MAXREVIVE,proc { |item,pkmn,scene|
    if !pkmn.fainted?
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    end
    pkmn.heal_HP
    pkmn.heal_status
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s HP was restored.",pkmn.name))
    next true
  })

ItemHandlers::UseOnPokemon.add(:ETHER,proc { |item,pkmn,scene|
    move = scene.pbChooseMove(pkmn,_INTL("Restore which move?"))
    next false if move<0
    if pbRestorePP(pkmn,move,10)==0
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    end
    scene.pbDisplay(_INTL("PP was restored."))
    next true
  })
  
  ItemHandlers::UseOnPokemon.add(:MAXETHER,proc { |item,pkmn,scene|
    move = scene.pbChooseMove(pkmn,_INTL("Restore which move?"))
    next false if move<0
    if pbRestorePP(pkmn,move,pkmn.moves[move].total_pp-pkmn.moves[move].pp)==0
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    end
    scene.pbDisplay(_INTL("PP was restored."))
    next true
  })
  
  ItemHandlers::UseOnPokemon.add(:ELIXIR,proc { |item,pkmn,scene|
    pprestored = 0
    for i in 0...pkmn.moves.length
      pprestored += pbRestorePP(pkmn,i,10)
    end
    if pprestored==0
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    end
    scene.pbDisplay(_INTL("PP was restored."))
    next true
  })
  
  ItemHandlers::UseOnPokemon.add(:MAXELIXIR,proc { |item,pkmn,scene|
    pprestored = 0
    for i in 0...pkmn.moves.length
      pprestored += pbRestorePP(pkmn,i,pkmn.moves[i].total_pp-pkmn.moves[i].pp)
    end
    if pprestored==0
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    end
    scene.pbDisplay(_INTL("PP was restored."))
    next true
  })

  ItemHandlers::UseInField.add(:SACREDASH,proc { |item|
    if $Trainer.pokemon_count == 0
      pbMessage(_INTL("There is no Pokémon."))
      next 0
    end
    canrevive = false
    for i in $Trainer.pokemon_party
      next if !i.fainted?
      canrevive = true; break
    end
    if !canrevive
      pbMessage(_INTL("It won't have any effect."))
      next 0
    end
    revived = 0
    pbFadeOutIn {
      scene = PokemonParty_Scene.new
      screen = PokemonPartyScreen.new(scene,$Trainer.party)
      screen.pbStartScene(_INTL("Using item..."),false)
      for i in 0...$Trainer.party.length
        if $Trainer.party[i].fainted?
          revived += 1
          $Trainer.party[i].heal
          screen.pbRefreshSingle(i)
          screen.pbDisplay(_INTL("{1}'s HP was restored.",$Trainer.party[i].name))
        end
      end
      if revived==0
        screen.pbDisplay(_INTL("It won't have any effect."))
      end
      screen.pbEndScene
    }
    next (revived==0) ? 0 : 3
  })