test:
	lualatex -interaction=nonstopmode -shell-escape test.tex

manual:
	pandoc -s -V fontfamily=libertine --toc-depth=4 -o lyluatex-tmp.tex lyluatex.md
	@echo Inserting examples
	@./insert-examples.lua lyluatex-tmp.tex lyluatex.tex || echo "Lua not found. Please make sure it's accessible in your PATH."
	latexmk lyluatex

clean:
	git clean -fXd

ctan: manual
	mkdir -p ./ctan/lyluatex
	cp -R lyluatex.sty lyluatex.lua \
		ly/ latexmkrc lyluatexbase.cls lyluatexmanual.cls \
		lyluatex.tex lyluatex.pdf LICENSE \
		./ctan/lyluatex/
	echo 'This material is subject to the MIT license.\n' > ./ctan/lyluatex/README.md
	echo '# Lyluatex' >> ./ctan/lyluatex/README.md
	sed -n -e '/## Usage/,$$p' README.en.md | sed '/test.en.tex/d' >> ./ctan/lyluatex/README.md
	(cd ctan/ ; zip -r lyluatex lyluatex)
