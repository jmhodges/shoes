Shoes.app :width => 500, :height => 500, :resizable => false do
  image 400, 470, :top => 30, :left => 50 do
    nostroke
    fill "#127"
    image 400, 250, :top => 230, :left => 0 do
      nostroke
      fill "#117"
      oval 70, 130, 260, 40
    end.blur(30)
    oval 10, 10, 380, 380
    image 400, 400, :top => 0, :left => 0 do
      nostroke
      fill "#46D"
      oval 30, 30, 338, 338
    end.blur(10)
    fill gradient(rgb(1.0, 1.0, 1.0, 0.7), rgb(1.0, 1.0, 1.0, 0.0))
    oval 80, 14, 240, 176
    image 400, 400, :top => 0, :left => 0 do
      nostroke
      fill "#79F"
      oval 134, 134, 130, 130
    end.blur(40)
    image 320, 260, :top => 150, :left => 40 do
      nostroke
      fill gradient(rgb(0.7, 0.9, 1.0, 0.0), rgb(0.7, 0.9, 1.0, 0.6))
      oval 60, 60, 200, 136
    end.blur(20)

    image 160, 50, :top => 182, :left => 150 do
      para "Shoes", :top => 0, :left => 0, :stroke => "#127", :size => 26
    end.blur(2)
    para "Shoes", :top => 180, :left => 148, :stroke => white, :size => 26
  end
end