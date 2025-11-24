CREATE function  [dbo].[fnc_strSplit] ( @string nvarchar(MAX), @splitter char( 1) )
returns @res table ( id int primary key, rank int, val nvarchar(MAX) )
as
begin
     if substring ( @string, len ( @string), 1)<>@splitter
          set @string= @string+@splitter
     declare @start int, @word nvarchar(MAX), @charindex int, @i int
     set @i=1
     set @start=1
     set @charindex= charindex( @splitter, @string, @start)
     while (@charindex <> 0)begin
          set @word= substring( @string, @start, @charindex - @start)
          set @start= @charindex +1
          set @charindex= charindex( @splitter, @string, @start)
          insert into @res  values ( @start, @i, LTrim(Rtrim(@word)))
          set @i=@i+1
     end
     return
end




