test:
	lualatex -interaction=nonstopmode -shell-escape test.tex

manual:
	pandoc --pdf-engine=lualatex \
		-V fontfamily=libertine \
		-o lyluatex.pdf \
		lyluatex.md

ctan:
	mkdir -p ./ctan/lyluatex
	cp lyluatex.* LICENSE ./ctan/lyluatex/
	echo 'This material is subject to the MIT license.\n' > ./ctan/lyluatex/README.md
	echo '# Lyluatex' >> ./ctan/lyluatex/README.md
	sed -n -e '/## Usage/,$$p' README.en.md | sed '/test.en.tex/d' >> ./ctan/lyluatex/README.md
	sed -n -e '/# Lyluatex/,$$p' ./ctan/lyluatex/README.md | pandoc -so ./ctan/lyluatex/lyluatex.tex
	sed -n -e '/# Lyluatex/,$$p' ./ctan/lyluatex/README.md | pandoc -o ./ctan/lyluatex/lyluatex.pdf
	(cd ctan/ ; zip -r lyluatex lyluatex)
