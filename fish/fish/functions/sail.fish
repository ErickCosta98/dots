function sail --description "Laravel Sail"
    set dir (pwd)

    while test "$dir" != /
        if test -f "$dir/vendor/bin/sail"
            cd "$dir"
            ./vendor/bin/sail $argv
            return
        end

        set dir (dirname "$dir")
    end

    echo "No se encontró un proyecto con Laravel Sail."
    return 1
end
