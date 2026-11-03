#!/usr/bin/env ruby
# Valide le frontmatter YAML (strict) des agents et des skills :
#   agents : name, description (tools recommandé) ; skills : name, description.
# Un frontmatter invalide casse silencieusement le chargement : à vérifier en CI.
require 'yaml'

errors = 0
warnings = 0
Dir.glob(['plugins/*/agents/*.md', 'plugins/*/skills/*/SKILL.md']).sort.each do |f|
  parts = File.read(f).split("---\n")
  begin
    fm = YAML.safe_load(parts[1].to_s)
    raise 'frontmatter absent ou non-objet' unless fm.is_a?(Hash)
    %w[name description].each { |k| raise "clé '#{k}' manquante ou vide" if fm[k].to_s.strip.empty? }
    if f.include?('/agents/') && fm['tools'].to_s.strip.empty?
      puts "::warning file=#{f}::pas de 'tools' (l'agent héritera de tous les outils)"
      warnings += 1
    end
  rescue StandardError => e
    puts "::error file=#{f}::#{e.message.lines.first.to_s.strip}"
    errors += 1
  end
end
puts "frontmatter : #{errors} erreur(s), #{warnings} avertissement(s)"
exit(errors.zero? ? 0 : 1)
