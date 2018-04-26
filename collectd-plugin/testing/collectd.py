class values:
  def __init__(self,v):
    self.data = v

  def dispatch(self,**kwargs):
    ti = 'none'
    ts = 'none'
    if hasattr(self, 'type_instance'):
      ti = self.type_instance
    if hasattr(self, 'time'):
      ts = self.time
    print 'here type=',self.data['type'],' type_instance=',ti,' values=',self.values,' timestamp=',ts

def Values(**kwargs):
  return values(kwargs)
