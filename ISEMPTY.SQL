if exists (select 1 from sys.objects where name = 'isempty')
begin 
  drop function isempty
end 
go
create function isempty(@string varchar(255))
returns char(1)
  
as begin

declare @return char(1),
               @datalen int

select @return = 'N'

select @datalen = datalength(ltrim(rtrim(@string ))) 

if @datalen = 0 or @datalen IS NULL
begin
  select @return = 'Y'
end

return @return

end                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  