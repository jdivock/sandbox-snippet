(function() {
    'use strict';

    $(document).ready(function() {
        // Init Skrollr
        var s = skrollr.init({
            render: function(data) {
                //Debugging - Log the current scroll position.
                console.log(data.curTop);
            }
        });

        window.onload = function() {
            $('section').height($(window).innerHeight());
            s.refresh();
        };

        $(window).resize(function() {
            $('section').height($(window).innerHeight());
            s.refresh();
        });
    });


})();
