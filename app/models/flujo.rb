class Flujo < ApplicationRecord
  has_many :set_metas_acciones, dependent: :destroy
  has_many :tarea_pendientes, dependent: :destroy
  has_many :mapa_de_actores, dependent: :destroy
  belongs_to :contribuyente
  belongs_to :tipo_instrumento
  belongs_to :proyecto, optional: true, dependent: :destroy
  belongs_to :manifestacion_de_interes, optional: true, dependent: :destroy #dependencia creada para poder instanciar y usar el id de manifestación dentro de la vista _table en tarea_pendiente 
  belongs_to :ppp, foreign_key: :programa_proyecto_propuesta_id, class_name: :ProgramaProyectoPropuesta, optional: true, dependent: :destroy
  has_one :adhesion, dependent: :destroy
  has_many :adhesion_elementos, through: :adhesion #DZC 2018-11-05 13:09:56 se agrega relación para efectos de la bandeja de entrada de la APL-032
  has_many :ppf_metas_establecimientos, dependent: :destroy

  has_many :auditorias, dependent: :destroy

  has_many :actividad_economica_flujos
  has_many :actividad_economicas, through: :actividad_economica_flujos

  has_many :comunas_flujos
  has_many :comunas, through: :comunas_flujos

  has_many :cuencas_flujo
  has_many :cuencas, through: :cuencas_flujo

  has_many :contribuyente_temporal, class_name: 'Contribuyente'
  has_many :usuario_temporal, class_name: 'User'

  accepts_nested_attributes_for :manifestacion_de_interes
  accepts_nested_attributes_for :ppp
  accepts_nested_attributes_for :proyecto

  APL = 'Acuerdo de Producción Limpia'
  FPL = 'Fondo de Producción Limpia'
  PPF = 'Programas y Proyectos de Financiamiento'



  def plazo_maximo_acciones_meses
    accion_plazo_mayor_anios = self.set_metas_acciones.where(plazo_unidad_tiempo: 0).order('plazo_valor DESC').first
    accion_plazo_mayor_meses = self.set_metas_acciones.where(plazo_unidad_tiempo: 1).order('plazo_valor DESC').first
    if accion_plazo_mayor_anios.nil? && accion_plazo_mayor_meses.nil?
      # si no hay accion pone plazo 0
      plazo = 0
    else
      plazo_anios = accion_plazo_mayor_anios.nil? ? 0 : accion_plazo_mayor_anios.plazo_valor*12
      plazo_meses = accion_plazo_mayor_meses.nil? ? 0 : accion_plazo_mayor_meses.plazo_valor
      plazo = plazo_anios > plazo_meses ? plazo_anios : plazo_meses
    end
    plazo
  end


  def nombre_instrumento
    nombre = "ACUERDO, PROYECTO O PROGRAMA NO INICIADO"
    if !self.proyecto.blank? 
      nombre = self.proyecto.nombre.blank? ? "Sin nombre": self.proyecto.nombre
    elsif !self.manifestacion_de_interes.blank?
      nombre = self.manifestacion_de_interes.nombre_acuerdo.blank? ? "Sin nombre": self.manifestacion_de_interes.nombre_acuerdo
    elsif !self.ppp.blank?
      nombre = self.ppp.nombre_propuesta.blank? ? "Sin nombre": self.ppp.nombre_propuesta
    end
    nombre
  end

  def tipo_de_flujo
    if self.manifestacion_de_interes_id.present?
      return "APL"
    end
    if self.programa_proyecto_propuesta_id.present?
      return "PPF"
    end 
    #verificar que es ppl
    if self.proyecto_id.present?
      return "PPL"
    end
  end

  def subtipo_de_instrumento
    no_hay = 'Pendiente de aprobación'
    case self.tipo_de_flujo
      when 'APL'
        self.manifestacion_de_interes.tipo_instrumento.present? ? self.manifestacion_de_interes.tipo_instrumento.nombre_subtipo : no_hay
      when 'PPF'
        self.ppp.tipo_instrumento.present? ? self.ppp.tipo_instrumento.nombre_subtipo : no_hay
      when 'PPL'
        self.proyecto.tipo_instrumento.present? ? self.proyecto.tipo_instrumento.nombre_subtipo : no_hay
      else
        no_hay
    end
  end

  #DZC se obtienen label para reporte automatizado de avances - historial de instrumentos
  def nombre_para_raa
    return "ID #{self.id} - #{self.tipo_de_flujo} - #{self.nombre_instrumento}"
  end

  def apl?
    self.manifestacion_de_interes_id.present?
  end

  def ppf?
    self.programa_proyecto_propuesta_id.present?
  end

  def fpl?
    self.proyecto_id.present?
  end

  def set_metas_acciones_by_estandar estandar_id
    estandar = EstandarHomologacion.find(estandar_id)
    #self.set_metas_acciones.clear
    estandar.estandar_set_metas_acciones.each do |set|      
      nuevo_set = self.set_metas_acciones.create
      nuevo_set.accion_id = set.accion_id
      nuevo_set.materia_sustancia_id = set.materia_sustancia_id
      nuevo_set.meta_id = set.meta_id
      nuevo_set.criterio_inclusion_exclusion = set.criterio_inclusion_exclusion
      nuevo_set.descripcion_accion = set.descripcion_accion
      nuevo_set.detalle_medio_verificacion = set.detalle_medio_verificacion
      nuevo_set.alcance_id = set.alcance_id
      nuevo_set.id_referencia = set.id
      nuevo_set.modelo_referencia = 'EstandarSetMetasAccion'
      nuevo_set.save(validate: false)
    end
    #self.manifestacion_de_interes.documento_diagnosticos.clear
    #estandar.referencias.each do |documento|
    #  nuevo_documento = DocumentoDiagnostico.new
    #  nuevo_documento.archivo = File.open(documento.file.file) if documento.present?
    #  nuevo_documento.nombre = documento.file.basename if documento.present?
    #  nuevo_documento.manifestacion_de_interes_id = self.manifestacion_de_interes.id
    #  nuevo_documento.desde_estandar = true
    #  nuevo_documento.save
    #end
  end

  def elementos_adheridos
    self.adhesiones.each do |f|
      
    end
  end

  # DZC 2018-10-17 13:03:17 devuelve la matriz de datos para la vista 'gestionar mis instumentos', para el array de personas_id del mismo usuario
  def datos_para_gestionar(personas_id)
    personas_id = [personas_id] if !personas_id.is_a?(Array)
    datos = []
    roles = []
    accion_texto = "Aún no creadas"
    accion_url = nil
    auditoria_texto = "Sin resultados"
    auditoria_url = nil
    usuario = nil
    tarea_pendiente = nil 
    objeto_uno = nil
    objeto_dos = nil
    objeto_tres = nil
    objeto_cuatro = nil
    establecimientos_id = []
    actividades = nil
    manifestacion_de_interes_id = self.manifestacion_de_interes_id
    
    # DZC 2018-10-18 15:42:09 obtengo los roles de las personas, y el usuario correspondiente
    actores = MapaDeActor.where(flujo_id: self.id, persona_id: personas_id)
    actores.each do |actor|
      roles += [actor.rol.nombre]
      usuario = usuario.nil? ? actor.persona.user : usuario
    end
    if usuario.present?
      case self.tipo_de_flujo
        when "APL"
          tareas_pendientes = self.tarea_pendientes.where(user_id: usuario.id, tarea_id: Tarea::ID_APL_013, estado_tarea_pendiente_id: EstadoTareaPendiente::NO_INICIADA)
          tarea_pendiente = tareas_pendientes.blank? ? nil : tareas_pendientes.first
          if tarea_pendiente.present? #DZC 2018-10-18 15:44:19 (1) usuario tiene la APL-013 pendiente
            accion_texto = "Acciones acordadas"
            accion_url = "cargar_actualizar_entregable_diagnostico_manifestacion_de_interes_path"
            objeto_uno = tarea_pendiente
            objeto_dos = self
          else #DZC 2018-10-18 15:44:51 usuario NO tiene la APL-013 como pendiente
            if self.set_metas_acciones.present? #DZC 2018-10-18 15:45:50 (2) pero hay un set de metas y acciones para mostrar
              accion_texto = "Acciones acordadas"
              accion_url = "apl_set_metas_acciones_admin_gestionar_mis_instrumentos_path"
              objeto_uno = self
            end
          end
          # DZC 2018-11-06 22:35:55 el usuario tiene resultados de auditoría
          if self.auditorias.present?
            auditoria_texto = "Resultados de auditorías"
            auditoria_url = "admin_reporte_automatizado_avances_path"
            objeto_tres = self
          end
        when "PPF"
          tareas_pendientes = self.tarea_pendientes.where(user_id: usuario.id, tarea_id: Tarea::ID_PPF_018, estado_tarea_pendiente_id: EstadoTareaPendiente::NO_INICIADA)
          tarea_pendiente = tareas_pendientes.blank? ? nil : tareas_pendientes.first
          if tarea_pendiente.present? #DZC 2018-10-18 15:48:24 (1) usuario tiene la PPF-018 pendiente
            
            accion_texto = "Actividades"
            accion_url = "ppf_tarea_pendiente_set_metas_acciones_path"
            objeto_uno = tarea_pendiente
          else #DZC 2018-10-18 15:50:04 usuario NO tiene la PPF-018 como pendiente
            
            if self.ppf_metas_establecimientos.present? #DZC 2018-10-18 15:50:20 (2) pero tiene al menos un establecimiento con set de metas y acciones para mostrar

              establecimientos_id = []
              if (actores.where(rol_id: [Rol::REVISOR_TECNICO, Rol::COORDINADOR, Rol::CARGADOR_DATOS_ACUERDO, Rol::RESPONSABLE_ENTREGABLES]).size > 0) 
                #DZC 2018-10-18 19:54:52 si posee alguno de estos roles puede ver las metas y acciones de todos los establecimientos
                establecimientos_id = self.ppf_metas_establecimientos.pluck(:establecimiento_contribuyente_id).uniq
              elsif (actores.where(rol_id: Rol::RESPONSABLE_CUMPLIMIENTO_COMPROMISOS).size > 0) 
                #DZC 2018-10-18 19:56:51 en cambio, si posee este rol solo puede ver las metas y acciones de su propio establecimiento

                responsables_id = actores.where(rol_id: Rol::RESPONSABLE_CUMPLIMIENTO_COMPROMISOS).pluck(:persona_id).uniq
                responsables_establecimiento_contribuyente_id = Persona.where(id: responsables_id).pluck(:establecimiento_contribuyente_id)

                establecimientos_id = self.ppf_metas_establecimientos.pluck(:establecimiento_contribuyente_id).uniq & responsables_establecimiento_contribuyente_id
              end

               #DZC 2018-10-19 11:05:41 si se encontraron establecimientos se ejecuta el path respectivo
              if !establecimientos_id.blank?
                accion_texto = "Actividades"
                accion_url = "ppf_set_metas_acciones_admin_gestionar_mis_instrumentos_path"
                objeto_uno = self
              end
            end
          end
          if self.auditorias.present?
            auditoria_texto = "Resultados de auditorías"
            auditoria_url = "admin_reporte_automatizado_avances_path"
            objeto_tres = self
          end

        when "PPL"
          tareas_pendientes = self.tarea_pendientes.where(user_id: usuario.id, tarea_id: Tarea::ID_FPL_007, estado_tarea_pendiente_id: EstadoTareaPendiente::NO_INICIADA)
          tarea_pendiente = tareas_pendientes.blank? ? nil : tareas_pendientes.first
          if tarea_pendiente.present?
            accion_texto = "Actividades"
            accion_url = "calendario_seguimiento_fpl_proyecto_path"
            objeto_uno = tarea_pendiente.id
            objeto_dos = self.proyecto
          else
            actividades = ProyectoActividad::get_actividades_calendario(proyecto.id)
            if actividades.present?
              accion_texto = "Actividades" 
              accion_url = "fpl_set_metas_acciones_admin_gestionar_mis_instrumentos_path"
              objeto_uno = self
            end
          end

          # DZC 2018-11-06 17:17:29 consideramos las tareas pendientes de rendiciones
          tareas_pendientes = self.tarea_pendientes.where(user_id: usuario.id, tarea_id: Tarea::ID_FPL_011, estado_tarea_pendiente_id: EstadoTareaPendiente::NO_INICIADA)
          tarea_pendiente = tareas_pendientes.blank? ? nil : tareas_pendientes.first
          if tarea_pendiente.present? # DZC 2018-11-06 17:41:30 el usuario tiene una FPL-011 pendiente
            auditoria_texto = "Estado de rendiciones"
            auditoria_url = "seguimiento_fpl_proyecto_rendicion_actividades_path"
            objeto_tres = tarea_pendiente
            objeto_cuatro = self.proyecto
          else # DZC 2018-11-06 17:41:59 no tiene una FPL-011
            # DZC 2018-11-06 17:42:09 pero tiene al menos
            

          end
      end
      datos << {
          tipo_instrumento: self.tipo_instrumento.nombre,
          subtipo_instrumento: self.subtipo_de_instrumento, 
          id_instrumento: self.id,
          manifestacion_de_interes_id: manifestacion_de_interes_id,
          nombre_instrumento: self.nombre_instrumento,
          roles: roles.sort.to_sentence,
          acciones_actividades: {
            texto: accion_texto,
            url: accion_url,
            objeto_uno: objeto_uno,
            objeto_dos: objeto_dos
          },
          establecimientos_id: establecimientos_id,
          auditorias_rendiciones: {
            texto: auditoria_texto,
            url: auditoria_url,
            objeto_uno: objeto_tres,
            objeto_dos: objeto_cuatro
          }
        }
    end
    datos
  end

  # DZC 2018-10-17 12:46:44 devuelve el listado de roles por usuario
  def roles_por_personas(personas_id) 
    personas_id = [personas_id] if !personas_id.is_a?(Array)
    actores = self.mapa_de_actores.where(persona_id: personas_id)
    roles = Rol.where(id: actores.pluck(:rol_id)).map{ |r| r.nombre}.sort
  end


  #DZC devuelve el listado de ids de tareas existentes en el flujo
  def tareas_del_flujo
    tareas_id = self.tarea_pendientes.pluck(:tarea_id).uniq
    Tarea.where(id: tareas_id).order(nombre: :asc)
  end

  #DZC devuelve la matriz de instancias históricas por flujo
  def instancias_del_flujo current_user
    instancias = []
    #Si es admin veo todo
    puedo_ver_tareas = current_user.is_admin?
    personas = current_user.personas
    personas_id = personas.pluck(:id)
    if !puedo_ver_tareas
      #jefe de linea ve todo lo relacionado a los tipos de instrumento donde es responsable
      #consulto directo a responsables
      jefes_de_linea = Responsable::__personas_responsables(Rol::JEFE_DE_LINEA, self.tipo_instrumento_id)
      puedo_ver_tareas = (personas_id & jefes_de_linea.map{|jl| jl.id}).size > 0

      if !puedo_ver_tareas
        #los roles descritos abajo ven todo lo relacionado al flujo
        #por eso consulto al mapa de actores, para saber cual fue su rol de participacion en el flujo
        roles = self.mapa_de_actores.where(persona_id: personas.pluck(:id)).pluck(:rol_id)
        puedo_ver_tareas = (roles & [Rol::COORDINADOR, Rol::RESPONSABLE_ENTREGABLES, Rol::REVISOR_TECNICO]).size > 0
      end
    end

    jefes_de_linea_coordinadores = Responsable::__personas_responsables([Rol::JEFE_DE_LINEA, Rol::COORDINADOR], self.tipo_instrumento_id)
    puedo_ver_descargable_apl_018 = (personas_id & jefes_de_linea_coordinadores.map{|jlc| jlc.id}).size > 0

    self.tareas_del_flujo.each do |t|
      documentos_asociados = {nombre: "Sin documentos asociados", url: "", parametros: [], metodo: false}
      tarea_pend = self.tarea_pendientes.where(tarea_id: t.id).first
      estado = tarea_pend.estado_tarea_pendiente.nombre_historial
      pendiente = (tarea_pend.estado_tarea_pendiente_id == EstadoTareaPendiente::ENVIADA) ? tarea_pend : nil
      #finalmente solo puede ver la tarea en especifico si es el que la respondio
      puedo_ver_tarea = puedo_ver_tareas
      puedo_ver_tarea = tarea_pend.user_id == current_user.id if !puedo_ver_tarea
      if t.es_convocatoria?
        instancia = Convocatoria.where(flujo_id: self.id, tarea_codigo: t.codigo).pluck(:nombre)
      elsif t.es_minuta?
        tps = self.tarea_pendientes.where(tarea_id: t.id)
        convocatorias_ids = []
        tps.each do |tp|
          convocatorias_ids << tp.data[:convocatoria_id] if (tp.data.present? && tp.data.has_key?(:convocatoria_id))
        end
        convocatorias_ids = convocatorias_ids.uniq
        instancia = Convocatoria.where(flujo_id: self.id, id: convocatorias_ids).order(nombre: :asc).pluck(:nombre)
      elsif t.es_auditoria?
        # 
        instancia = []
        contador = 0
        self.auditorias.each do |aud|
          # 
          instancia << (aud.nombre.blank? ? "Sin nombre-#{contador+1}" : aud.nombre)
        end
      else
        instancia = ["Única"]
      end
      if t.codigo == Tarea::COD_APL_005
        documentos_asociados = {nombre: "Manifestación de Interés", url: 'descargar_manifestacion_pdf_admin_historial_instrumentos_path', parametros: [self.manifestacion_de_interes_id], metodo: true}
      elsif t.codigo == Tarea::COD_APL_018# && estado == "Ejecutada"
        informe_acuerdo = self.manifestacion_de_interes.informe_acuerdo
        if !informe_acuerdo.nil? && (tarea_pend.user_id == current_user.id || puedo_ver_descargable_apl_018)
          documentos_asociados = {nombre: "Documento de Acuerdo", url: 'obtener_archivo_acuerdo_anexos_zip_path', parametros: [self.id], metodo: true }
        end
      elsif t.codigo == Tarea::COD_APL_019
        #solo si es admin puede descargar el documento
        if current_user.is_admin?
          #agregamos documento personalizado para tarea APL-019
          documentos_asociados = {nombre: "Observaciones de Informe y de Metas y Acciones", url: 'descargar_observaciones_informe_metas_acciones_admin_historial_instrumentos_path', parametros: [self.manifestacion_de_interes_id], metodo: true}
        end
      elsif t.codigo == Tarea::COD_APL_042
        if self.tarea_pendientes.where(tarea_id: [Tarea::ID_APL_041, Tarea::ID_APL_042]).where(estado_tarea_pendiente_id: EstadoTareaPendiente::NO_INICIADA).length == 0
          documentos_asociados = {nombre: 'Informe de Impacto', url: self.manifestacion_de_interes.informe_impacto.documento.url}
        end
      elsif t.codigo == Tarea::COD_APL_039
        if current_user.is_admin?
          documentos_asociados = {nombre: 'Encuestas diagnóstico general', url: "modal"}
          lista = {}
          self.tarea_pendientes.where(tarea_id: t.id).each do |tp|
            auditoria = tp.determina_auditoria
            lista[auditoria.id] = {nombre: auditoria.nombre, id: auditoria.id} if !lista.has_key?(auditoria.id)
          end
          documentos_asociados[:lista] = lista.values
        end
      elsif t.es_una_encuesta && t.codigo != Tarea::COD_APL_039
        #solo si es admin puede descargar el documento
        if current_user.is_admin?
          nombre_boton = "Resultado encuesta"
          nombre_boton = "Encuesta diagnóstico general" if t.codigo == Tarea::COD_APL_015

          documentos_asociados = {nombre: nombre_boton, url: 'descargar_respuesta_encuesta_admin_historial_instrumentos_path', parametros: [self.manifestacion_de_interes_id, t.id], metodo: true}
        end
      
      end
      tareas_auditoria = {}
      if t.codigo == Tarea::COD_APL_033
        self.tarea_pendientes.where(tarea_id: t.id).each do |tp|
          auditoria = tp.determina_auditoria
          tareas_auditoria[auditoria.id] = {nombre: auditoria.nombre, id: auditoria.id, tarea_pendiente_id: tp.id} if !tareas_auditoria.has_key?(auditoria.id)
        end
        tareas_auditoria = tareas_auditoria.values
      end
      tareas_validaciones = {}
      if t.codigo == Tarea::COD_APL_034
        self.tarea_pendientes.where(tarea_id: t.id).order(data: :asc).each do |tp|
          auditoria = tp.determina_auditoria
          tareas_validaciones[tp.user_id] = {nombre: tp.user.nombre_completo, validaciones: []} if !tareas_validaciones.has_key?(tp.user_id)
          tareas_validaciones[tp.user_id][:validaciones] << {nombre: auditoria.nombre, tarea_pendiente_id: tp.id, finalizada: tp.no_esta_pendiente?}
        end
        tareas_validaciones = tareas_validaciones.values
        estado = "Ejecutada"
      end
      instancias << {
        tipo_instrumento: self.tipo_instrumento.nombre,
        id_instrumento: self.id,
        nombre_instrumento: self.nombre_instrumento,
        tarea: t,
        manifestacion_de_interes: self.manifestacion_de_interes,
        nombre_tarea: t.nombre,
        responsables: t.responsables_de_la_tarea(self.id),
        documentos_asociados: documentos_asociados,
        instancia: instancia,
        estado: estado,
        pendiente: pendiente,
        puedo_ver_tarea: puedo_ver_tarea,
        auditorias_tarea_033: tareas_auditoria,
        validaciones_tarea_034: tareas_validaciones
      } 
    end
    instancias
  end

  # DZC 2018-10-30 15:31:04 devuelve el listado de usuarios con tareas pendientes en el flujo
  def usuarios_con_tarea_pendiente
    usuarios_con_tareas_pendientes = self.tarea_pendientes.where(estado_tarea_pendiente_id: EstadoTareaPendiente::NO_INICIADA).pluck(:user_id).uniq
    User.where(id: usuarios_con_tareas_pendientes)
  end

  # DZC 2018-10-30 17:26:43 devuelve el listado de actores con tareas pendientes en el flujo
  def actores_con_tareas_pendientes
    personas_id = Persona.where(user_id: self.usuarios_con_tarea_pendiente.pluck(:id)).pluck(:id)
    self.mapa_de_actores.where(persona_id: personas_id)
  end

  # DZC 2018-10-30 17:27:00 devuelve los ruts de los actores con tareas pendientes en el flujo
  def ruts_actores_con_tareas_pendientes
    actores_con_tareas_pendientes = self.actores_con_tareas_pendientes.pluck(:persona_id).uniq
    personas_con_tarea_pendiente = Persona.where(id: actores_con_tareas_pendientes).pluck(:user_id).uniq
    User.where(id: personas_con_tarea_pendiente).pluck(:rut).uniq
  end


  def tipo_instrumento_por_proceso
    if !self.proyecto.blank? 
      instrumento = self.proyecto.nombre.blank? ? "Sin nombre": self.proyecto.nombre
    elsif !self.manifestacion_de_interes.blank?
      instrumento = self.manifestacion_de_interes.nombre_acuerdo.blank? ? "Sin nombre": self.manifestacion_de_interes.nombre_acuerdo
    elsif !self.ppp.blank?
      instrumento = self.ppp.nombre_propuesta.blank? ? "Sin nombre": self.ppp.nombre_propuesta
    end
    instrumento
  end


  # DZC 2018-11-06 14:04:30 duplica todas las tareas pendientes por rol de origen para el rol/usuario en el flujo actual
  def duplica_pendientes_para_responsable_especifico(usuario_destino_id, rol_id=Rol::RESPONSABLE_ENTREGABLES)
    (usuario_destino_id = usuario_destino_id.is_a?(Array)? usuario_destino_id : [usuario_destino_id])

    actores_por_mapa_de_actor = self.mapa_de_actores.where(rol_id: rol_id).uniq
    personas_por_mapa_de_actor_id = actores_por_mapa_de_actor.pluck(:persona_id).uniq
    personas_por_mapa_de_actor = Persona.where(id: personas_por_mapa_de_actor_id).uniq

    
    contribuyentes_id = personas_por_mapa_de_actor.pluck(:contribuyente_id).uniq

    personas_por_tabla_responsables_id = Responsable.responsables_por_rol(rol_id, contribuyentes_id, self.tipo_instrumento_id).pluck(:id).uniq

    personas_id = personas_por_mapa_de_actor_id + personas_por_tabla_responsables_id

    usuarios_id = User.includes([:personas]).where("personas.id" => personas_id).pluck(:id)

    tareas_id = Tarea.where(rol_id: rol_id).pluck(:id)
    
    self.tarea_pendientes.where(tarea_id: tareas_id, estado_tarea_pendiente_id: EstadoTareaPendiente::NO_INICIADA, user_id: usuarios_id).each do |tp|
      usuario_destino_id.each do |ud|
        
        TareaPendiente.find_or_create_by(
          flujo_id: self.id,
          tarea_id: tp.tarea_id,
          estado_tarea_pendiente: tp.estado_tarea_pendiente,
          user_id: ud,
          data: tp.data,
          resultado: tp.resultado,
          primera_ejecucion: tp.primera_ejecucion 
        )     
      end     
    end
  end

end
