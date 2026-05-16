set number
set relativenumber


nnoremap <A-j> :m .+1<CR>==
nnoremap <A-k> :m .-2<CR>==

inoremap <A-j> <Esc>:m .+1<CR>==gi
inoremap <A-k> <Esc>:m .-2<CR>==gi

vnoremap <A-j> :m '>+1<CR>gv=gv
vnoremap <A-k> :m '<-2<CR>gv=gv

set keymap=russian-jcukenwin
set iminsert=0
set imsearch=-1
set showmode
