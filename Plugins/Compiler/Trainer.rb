module GameData
	class Trainer
		attr_reader :policies
	
		SCHEMA = {
		  "Items"        => [:items,         "*e", :Item],
		  "LoseText"     => [:lose_text,     "s"],
		  "Policies"	 => [:policies,		 "*e", :Policy],
		  "Pokemon"      => [:pokemon,       "ev", :Species],   # Species, level
		  "Form"         => [:form,          "u"],
		  "Name"         => [:name,          "s"],
		  "Moves"        => [:moves,         "*e", :Move],
		  "Ability"      => [:ability,       "s"],
		  "AbilityIndex" => [:ability_index, "u"],
		  "Item"         => [:item,          "e", :Item],
		  "Gender"       => [:gender,        "e", { "M" => 0, "m" => 0, "Male" => 0, "male" => 0, "0" => 0,
													"F" => 1, "f" => 1, "Female" => 1, "female" => 1, "1" => 1 }],
		  "Nature"       => [:nature,        "e", :Nature],
		  "IV"           => [:iv,            "uUUUUU"],
		  "EV"           => [:ev,            "uUUUUU"],
		  "Happiness"    => [:happiness,     "u"],
		  "Shiny"        => [:shininess,     "b"],
		  "Shadow"       => [:shadowness,    "b"],
		  "Ball"         => [:poke_ball,     "s"],
		}
		
		def initialize(hash)
		  @id             = hash[:id]
		  @id_number      = hash[:id_number]
		  @trainer_type   = hash[:trainer_type]
		  @real_name      = hash[:name]         || "Unnamed"
		  @version        = hash[:version]      || 0
		  @items          = hash[:items]        || []
		  @real_lose_text = hash[:lose_text]    || "..."
		  @pokemon        = hash[:pokemon]      || []
		  @policies		  = hash[:policies]		|| []
		  @pokemon.each do |pkmn|
			GameData::Stat.each_main do |s|
			  pkmn[:iv][s.id] ||= 0 if pkmn[:iv]
			  pkmn[:ev][s.id] ||= 0 if pkmn[:ev]
			end
		  end
		end
	
		# Creates a battle-ready version of a trainer's data.
		# @return [Array] all information about a trainer in a usable form
		def to_trainer
		  # Determine trainer's name
		  tr_name = self.name
		  Settings::RIVAL_NAMES.each do |rival|
			next if rival[0] != @trainer_type || !$game_variables[rival[1]].is_a?(String)
			tr_name = $game_variables[rival[1]]
			break
		  end
		  # Create trainer object
		  trainer = NPCTrainer.new(tr_name, @trainer_type)
		  trainer.id        = $Trainer.make_foreign_ID
		  trainer.items     = @items.clone
		  trainer.lose_text = self.lose_text
		  trainer.policies  = self.policies
		  # Create each Pokémon owned by the trainer
		  @pokemon.each do |pkmn_data|
			species = GameData::Species.get(pkmn_data[:species]).species
			pkmn = Pokemon.new(species, pkmn_data[:level], trainer, false)
			trainer.party.push(pkmn)
			# Set Pokémon's properties if defined
			if pkmn_data[:form]
			  pkmn.forced_form = pkmn_data[:form] if MultipleForms.hasFunction?(species, "getForm")
			  pkmn.form_simple = pkmn_data[:form]
			end
			pkmn.item = pkmn_data[:item]
			if pkmn_data[:moves] && pkmn_data[:moves].length > 0
			  pkmn_data[:moves].each { |move| pkmn.learn_move(move) }
			else
			  pkmn.reset_moves
			end
			pkmn.ability_index = pkmn_data[:ability_index]
			pkmn.ability = pkmn_data[:ability]
			pkmn.gender = pkmn_data[:gender] || ((trainer.male?) ? 0 : 1)
			pkmn.shiny = (pkmn_data[:shininess]) ? true : false
			if pkmn_data[:nature]
			  pkmn.nature = pkmn_data[:nature]
			else
			  nature = pkmn.species_data.id_number + GameData::TrainerType.get(trainer.trainer_type).id_number
			  pkmn.nature = nature % (GameData::Nature::DATA.length / 2)
			end
			GameData::Stat.each_main do |s|
			  if pkmn_data[:iv]
				pkmn.iv[s.id] = pkmn_data[:iv][s.id]
			  else
				pkmn.iv[s.id] = [pkmn_data[:level] / 2, Pokemon::IV_STAT_LIMIT].min
			  end
			  if pkmn_data[:ev]
				pkmn.ev[s.id] = pkmn_data[:ev][s.id]
			  else
				pkmn.ev[s.id] = [pkmn_data[:level] * 3 / 2, Pokemon::EV_LIMIT / 6].min
			  end
			end
			pkmn.happiness = pkmn_data[:happiness] if pkmn_data[:happiness]
			pkmn.name = pkmn_data[:name] if pkmn_data[:name] && !pkmn_data[:name].empty?
			if pkmn_data[:shadowness]
			  pkmn.makeShadow
			  pkmn.update_shadow_moves(true)
			  pkmn.shiny = false
			end
			pkmn.poke_ball = pkmn_data[:poke_ball] if pkmn_data[:poke_ball]
			pkmn.calc_stats
		  end
		  return trainer
		end
	end
end