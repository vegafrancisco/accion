class ManifestacionDeInteresController < ApplicationController
  before_action :authenticate_user!, unless: proc { action_name == 'google_map_kml' }
  before_action :set_tarea_pendiente, except: [:iniciar_flujo]
  before_action :set_flujo, except: [:iniciar_flujo]
  before_action :set_manifestacion_de_interes, only: [:edit, :update, :destroy, :descargable, 
    :revisor, :asignar_revisor, :admisibilidad, :revisar_admisibilidad, 
                                      :observaciones_admisibilidad, :resolver_observaciones_admisibilidad,
                                      :pertinencia_factibilidad, :revisar_pertinencia_factibilidad,
                                      :responder_pertinencia_factibilidad, :responder_cond_obs_pertinencia_factibilidad,
                                      :usuario_entregables, :guardar_usuario_entregables,
                                      :firma, :actualizar_firma,
                                      :carga_auditoria, :enviar_carga_auditoria,:cargar_actualizar_entregable_diagnostico,
                                      :revisar_entregable_diagnostico,
                                      :evaluacion_negociacion, :actualizar_acuerdos_actores,:actualizar_comite_acuerdos]
  before_action :set_representantes, only: [:edit, :update, :destroy, :descargable, 
    :revisor, :asignar_revisor, :admisibilidad, :revisar_admisibilidad, 
                                      :observaciones_admisibilidad, :resolver_observaciones_admisibilidad,
                                      :pertinencia_factibilidad, :revisar_pertinencia_factibilidad,
                                      :responder_pertinencia_factibilidad, :responder_cond_obs_pertinencia_factibilidad,
                                      :usuario_entregables, :guardar_usuario_entregables,
                                      :firma, :actualizar_firma,
                                      :carga_auditoria, :enviar_carga_auditoria,:cargar_actualizar_entregable_diagnostico,
                                      :revisar_entregable_diagnostico,
                                      :evaluacion_negociacion, :actualizar_acuerdos_actores,:actualizar_comite_acuerdos]
  before_action :set_contribuyentes, only: [:edit,:update, 
                                      :admisibilidad, :revisar_admisibilidad, 
                                      :observaciones_admisibilidad, :resolver_observaciones_admisibilidad,
                                      :pertinencia_factibilidad, :revisar_pertinencia_factibilidad,
                                      :responder_pertinencia_factibilidad, :responder_cond_obs_pertinencia_factibilidad,
                                      :usuario_entregables, :guardar_usuario_entregables, 
                                      :firma, :actualizar_firma,
                                      :carga_auditoria, :enviar_carga_auditoria]
  before_action :set_tipo_instrumentos, only: [:edit,:update, 
                                      :admisibilidad, :revisar_admisibilidad, 
                                      :observaciones_admisibilidad, :resolver_observaciones_admisibilidad,
                                      :pertinencia_factibilidad, :revisar_pertinencia_factibilidad,
                                      :responder_pertinencia_factibilidad, :responder_cond_obs_pertinencia_factibilidad,
                                      :usuario_entregables, :guardar_usuario_entregables, 
                                      :firma, :actualizar_firma,
                                      :carga_auditoria, :enviar_carga_auditoria]
  before_action :set_archivo_mapa_actores, only: [:edit]

  def iniciar_flujo #DZC TAREA APL-001 al iniciar proceso
    warning   = nil
    success   = nil
    errors    = nil
    
    if @personas.blank?
      warning = 'Este usuario no esta asociado a ninguna institución, por lo tanto no puede iniciar el proceso.'
    else
      personas_proponentes = current_user.personas & Responsable.responsables_por_rol(Rol::PROPONENTE,nil,TipoInstrumento::ACUERDO_DE_PRODUCCION_LIMPIA)
      if personas_proponentes.blank?
        warning = 'Usted NO puede iniciar Acuerdos ya que no cumple con los requisitos para ser PROPONENTE.'
      else
        flujo = Flujo.new({
          contribuyente_id: personas_proponentes.first[:contribuyente_id],
          tipo_instrumento_id: TipoInstrumento::ACUERDO_DE_PRODUCCION_LIMPIA
        })
        if flujo.save
          tarea_manifestacion = Tarea.find_by_codigo(Tarea::COD_APL_001)
          flujo.tarea_pendientes.create([{ 
              tarea_id: tarea_manifestacion.id,
              estado_tarea_pendiente_id: EstadoTareaPendiente::NO_INICIADA,
              user_id: current_user.id,
              data: { }
            }]
          )
          success = 'Flujo manifestación de interés creado correctamente.'
        end
      end
    end
    respond_to do |format|
      format.html { redirect_to root_path, flash: { warning: warning, success: success, error: errors } }
    end
  end

  def destroy
    @manifestacion_de_interes.destroy
    redirect_to root_path, notice: 'Manifestación correctamente eliminada.'
  end

  def create #DZC TAREA APL-001 al iniciar proceso
    success         = nil
    error           = nil
    link            = root_url
    tarea_pendiente = TareaPendiente.find(params[:tarea_pendiente_id]) rescue nil
    autorizado? tarea_pendiente

    if tarea_pendiente.blank?
      error = 'Acceso inválido a tarea seleccionada'
    else
      if tarea_pendiente.data.blank? || ! tarea_pendiente.data.has_key?(:manifestacion_de_interes_id)
        manifestacion_de_interes = ManifestacionDeInteres.new
        if manifestacion_de_interes.save
          tarea_pendiente.data = { manifestacion_de_interes_id: manifestacion_de_interes.id }
          if tarea_pendiente.save
            flujo = tarea_pendiente.flujo
            flujo.manifestacion_de_interes_id = manifestacion_de_interes.id
            flujo.save
            success = 'Manifestación correctamente creada.'
          end
        else
          p manifestacion_de_interes.errors.messages
          error = 'Problema al generar manifestacion'
        end
      else
        manifestacion_de_interes = ManifestacionDeInteres.find(tarea_pendiente.data[:manifestacion_de_interes_id]) rescue nil
      end
      unless manifestacion_de_interes.blank?
        p manifestacion_de_interes
        link = edit_manifestacion_de_interes_path(tarea_pendiente,manifestacion_de_interes)
      end
    end

    respond_to do |format|
      format.html { redirect_to link, flash: { success: success, error: error }}
    end
  end

  def edit #DZC TAREA APL-001 una vez instanciada la manifestación
    # DZC 2019-02-28 18:03:15 se setean las varibles relativas al mensaje "Recuerde gradar sus cambios"
    @recuerde_guardar_minutos = ManifestacionDeInteres::MINUTOS_MENSAJE_GUARDAR
  end

  def update #DZC TAREA APL-001 una vez instanciada la manifestación
    
    @manifestacion_de_interes.assign_attributes(manifestacion_params)
    @manifestacion_de_interes.completar_informacion!
    set_representantes

    unless @manifestacion_de_interes.tipo_instrumento.blank?
      @manifestacion_de_interes.descripcion_acuerdo = @manifestacion_de_interes.tipo_instrumento.descripcion
    end

    checked = @manifestacion_de_interes.set_checked
    @rpc_checked = checked[:rpc_checked]
    @actecos_checked = checked[:actecos_checked]
    respond_to do |format|
      @manifestacion_de_interes.tarea_codigo = @tarea.codigo
      if @manifestacion_de_interes.valid?    
        if @manifestacion_de_interes.save                    
          # DZC 2018-10-10 16:47:12 se modifica cambiando el contribuyente en el flujo en concordancia al que se seleccionó en la manifestación
          @flujo.update(contribuyente_id: @manifestacion_de_interes.contribuyente_id) if !@manifestacion_de_interes.contribuyente_id.blank?
          if manifestacion_params[:temporal]=="false" || manifestacion_params[:temporal].blank?
            @tarea_pendiente.pasar_a_siguiente_tarea
            # @tarea_pendiente.estado_tarea_pendiente_id = EstadoTareaPendiente::ENVIADA
            #revisar para optimizar con método de Adan en modelo tarea_pendiente
            # if @tarea_pendiente.save
            #   flujo_tareas = FlujoTarea.where(tarea_entrada_id: @tarea_pendiente.tarea_id).all
            #   flujo_tareas.each do |ft|
            #     ft.continuar_flujo @tarea_pendiente.flujo_id
            #   end
            # end
            success = 'Manifestación Enviada'
            format.js { 
              flash[:success] = success 
              render js: "window.location='#{root_path}'"
            }
            format.html { redirect_to root_path, notice: success }
          else
            # DZC 2019-02-28 18:03:15 se setean las varibles relativas al mensaje "Recuerde gradar sus cambios"
            @recuerde_guardar_minutos = ManifestacionDeInteres::MINUTOS_MENSAJE_GUARDAR           

            @mantener_temporal = manifestacion_params[:temporal] 
            success = 'Manifestación correctamente actualizada.'
            format.js { flash.now[:success] = success }
            format.html { redirect_to root_path, notice: success }         
          end
          # if @manifestacion_de_interes.save
          #   procesa_mapa_actores
          # end

          # if @manifestacion_de_interes.save
          #   #DZC pobla las tablas con los datos del excel
          #   #DZC convierto el hash con string keys a hash_with_indiferent_access, y de vuelta a hash con key simbólicas, o nil, según corresponda
          #   actores_desde_campo = @manifestacion_de_interes.mapa_de_actores_data.blank? ? nil : @manifestacion_de_interes.mapa_de_actores_data.map{|i| i.transform_keys!(&:to_sym).to_h}
          #   if !actores_desde_campo.nil? 
          #     MapaDeActor.actualiza_tablas_mapa_actores(@actores_desde_campo, @flujo, @tarea_pendiente)
          #   end
          # end
          # format.js { flash.now[:success] = success }
          # format.html { redirect_to root_path, notice: success }
        end
        # if @manifestacion_de_interes.save
        #   # procesa_mapa_actores
        #   # @manifestacion_de_interes.data_mapa_de_actores #DZC no es necesario, por que el modelo lo ejecuta como after_save
        # end
        # if @manifestacion_de_interes.save
        #   #DZC pobla las tablas con los datos del excel
        #   #DZC convierto el hash con string keys a hash_with_indiferent_access, y de vuelta a hash con key simbólicas, o nil, según corresponda
        #   actores_desde_campo = @manifestacion_de_interes.mapa_de_actores_data.blank? ? nil : @manifestacion_de_interes.mapa_de_actores_data.map{|i| i.transform_keys!(&:to_sym).to_h}
        #   if !actores_desde_campo.nil? 
        #     MapaDeActor.actualiza_tablas_mapa_actores(@actores_desde_campo, @flujo, @tarea_pendiente)
        #   end
        # end
        format.js { flash.now[:success] = success }
        format.html { redirect_to root_path, notice: success }
      else
        @total_de_errores_por_tab = @manifestacion_de_interes.errores_agrupados
        if @manifestacion_de_interes.temporal.blank?
          flash.now[:error] = "Antes de enviar la manifestación debe completar todos los campos requeridos"
        end
        format.js { }
        format.html { render :edit }
      end
    end
  end

  def revisor #DZC TAREA APL-002
  end

  def asignar_revisor #DZC TAREA APL-002
    @manifestacion_de_interes.assign_attributes(manifestacion_revisor_params)
    respond_to do |format|
      @manifestacion_de_interes.tarea_codigo = @tarea.codigo
      if @manifestacion_de_interes.valid?
        @manifestacion_de_interes.save
        mapa = MapaDeActor.find_or_create_by({
          flujo_id: @tarea_pendiente.flujo_id,
          # rol_id: Rol::REVISOR_TECNICO,
          rol_id: Rol.find_by(nombre: 'Revisor Técnico').id, #DZC se reemplaza la constante por el valor del registro en la tabla. ESTO NO EVITA QUE SE DEBA MANTENER EL NOMBRE EN LA TABLA
          persona_id: manifestacion_revisor_params[:revisor_id]
        })
        continua_flujo_segun_tipo_tarea
        # @tarea_pendiente.pasar_a_siguiente_tarea 'A' #hasta el momento solo hay una condición en el flujo de esta tarea
        format.js { flash.now[:success] = 'Revisor asignado correctamente' ; render js: "window.location='#{root_path}'"
        }
        # format.html { redirect_to revisor_manifestacion_de_interes_path(@tarea_pendiente,@manifestacion_de_interes), flash: {notice: 'Revisor asignado correctamente' }}
        format.html { redirect_to root_path(@tarea_pendiente,@manifestacion_de_interes), flash: {notice: 'Revisor asignado correctamente' }}
      else
        format.js { }
        format.html { redirect_to root_path(@tarea_pendiente,@manifestacion_de_interes), flash: {error: 'Problema al asignar revisor' }}
      end
    end
  end

  def admisibilidad #DZC TAREA APL-003
  end

  def revisar_admisibilidad  #DZC TAREA APL-003
    @manifestacion_de_interes.assign_attributes(manifestacion_admisibilidad_params)
    @manifestacion_de_interes.tarea_codigo = @tarea.codigo
    respond_to do |format|
      if @manifestacion_de_interes.valid?
        @manifestacion_de_interes.save # Al estar comentada no guardaba los comentarios.-
        #En caso de seleecionar como representante a un usuario que no se encuentra dentro de la institucion cogestora, se debe agreagrar.-
        if @nuevo_usuario         
          usuario = User.find_by_id(@manifestacion_de_interes.representante_institucion_para_solicitud_id)
          contribuyente = @manifestacion_de_interes.contribuyente_id
          persona = usuario.persona_segun_(contribuyente)
          if persona.present?
            persona.persona_cargos.create(cargo_id: Cargo::ENCARGADO_INS)
          else
            persona = Persona.create(user_id: usuario.id, contribuyente_id: contribuyente,email_institucional: @manifestacion_de_interes.email_representante_para_acuerdo,telefono_institucional: @manifestacion_de_interes.telefono_representante_para_acuerdo)
            persona.persona_cargos.create(cargo_id: Cargo::ENCARGADO_INS)
          end
        end
        # @tarea_pendiente.estado_tarea_pendiente_id = EstadoTareaPendiente::ENVIADA
        if @tarea_pendiente.save
          continua_flujo_segun_tipo_tarea
          # #DZC se agrega la validación de la condición 'C', para ser coherente con el método continuar_flujo
          # case @manifestacion_de_interes.resultado_admisibilidad
          # when "aceptado"
          #   @tarea_pendiente.pasar_a_siguiente_tarea 'A'
          # when "en_observación"
          #   @tarea_pendiente.pasar_a_siguiente_tarea 'B'
          # when "rechazado"
          #   @tarea_pendiente.pasar_a_siguiente_tarea 'C'
          # end
        end
        format.js { flash.now[:success] = 'Admisibilidad enviada correctamente' 
          render js: "window.location='#{root_path}'"}
        format.html { redirect_to root_path, flash: {notice: 'Admisibilidad enviada correctamente' }}
      else
        flash.now[:error] = "Antes de enviar debe completar todos los campos requeridos"
        format.js { }
        format.html { render :admisibilidad}
      end
    end
  end

  def observaciones_admisibilidad #DZC APL-004
    unless @manifestacion_de_interes.secciones_observadas_admisibilidad.nil?
      @total_de_errores_por_tab = @manifestacion_de_interes.secciones_observadas_admisibilidad.map{|s| [s.to_sym, [""]]}.to_h
    end
  end

  def resolver_observaciones_admisibilidad #DZC TAREA APL-004 
    @manifestacion_de_interes.assign_attributes(manifestacion_obs_admisibilidad_params)
    unless @manifestacion_de_interes.secciones_observadas_admisibilidad.nil?
      @total_de_errores_por_tab = @manifestacion_de_interes.secciones_observadas_admisibilidad.map{|s| [s.to_sym, [""]]}.to_h
    end
    respond_to do |format|
      if @manifestacion_de_interes.valid?
      #DZC verifica la vigencia del plazo de 25 días corridos para evacuar las observaciones (condición 'B')
        if @manifestacion_de_interes.plazo_vigente? @manifestacion_de_interes.fecha_observaciones_admisibilidad, 25
          @manifestacion_de_interes.tarea_codigo = @tarea.codigo
          @manifestacion_de_interes.save
          #DZC corrige continuación el en flujo por cumplimiento de condición 'A'          
          if manifestacion_params[:temporal]=="false" || manifestacion_params[:temporal].blank?
            if manifestacion_obs_admisibilidad_params.key?(:update_obs_admisibilidad)
              @tarea_pendiente.pasar_a_siguiente_tarea 'A' if manifestacion_obs_admisibilidad_params[:update_obs_admisibilidad] == "true"
            end
            format.js { flash[:success] = 'Admisibilidad Enviada correctamente' 
              render js: "window.location='#{root_path}'"}
            format.html { redirect_to root_path, flash: {notice: 'Admisibilidad Enviada correctamente' }}
          else
            @mantener_temporal = manifestacion_params[:temporal] 
            success = 'Admisibilidad Actualizada correctamente'
            format.js { flash.now[:success] = success }
            format.html { redirect_to root_path, notice: success }         
          end
          format.js { flash.now[:success] = 'Admisibilidad Actualizada correctamente' 
            render js: "window.location='#{root_path}'"}
          format.html { redirect_to root_path, flash: {notice: 'Admisibilidad Actualizada correctamente' }}
        else
          @tarea_pendiente.pasar_a_siguiente_tarea 'B' #DZC pasa a siguiente tarea ejecutando condición 'B' (pone término al flujo)
          format.js { flash.now[:error] = 'Ya se ha vencido el plazo para evacuar las observaciones. Se ha puesto término a la manifestación'; render js: "window.location='#{root_path}'" }
          format.html { redirect_to root_path(@tarea_pendiente,@manifestacion_de_interes), flash: {notice: 'Ya se ha vencido el plazo para evacuar las observaciones. Se ha puesto término a la manifestación' }}
        end
      else
        @total_de_errores_por_tab = [] if @manifestacion_de_interes.secciones_observadas_admisibilidad.nil?
        @total_de_errores_por_tab[:"admisibilidad"] = [""]
        format.js { flash.now[:error] = "Antes de enviar debe completar todos los campos requeridos" }
        format.html { render :observaciones_admisibilidad }
      end
    end
  end

  def pertinencia_factibilidad #DZC TAREA APL-005
    # @responsables = Responsable.__personas_responsables(Rol::COORDINADOR, TipoInstrumento::ACUERDO_DE_PRODUCCION_LIMPIA)
    @responsables = Responsable.__personas_responsables(Rol.find_by(nombre: 'Coordinador').id, TipoInstrumento.find_by(nombre: 'Acuerdo de Producción Limpia').id) #DZC se reemplaza la constante por el valor del registro en la tabla. ESTO NO EVITA QUE SE DEBA MANTENER EL NOMBRE EN LA TABLA
  end

  def revisar_pertinencia_factibilidad #DZC TAREA APL-005
    @manifestacion_de_interes.assign_attributes(manifestacion_pertinencia_params)
    respond_to do |format|
      @manifestacion_de_interes.tarea_codigo = @tarea.codigo
      if @manifestacion_de_interes.valid?
        @manifestacion_de_interes.save
        mapa = MapaDeActor.find_or_create_by({
          flujo_id: @tarea_pendiente.flujo_id,
          rol_id: Rol::COORDINADOR,
          persona_id: manifestacion_pertinencia_params[:coordinador_subtipo_instrumento_id]
        })
        if @tarea_pendiente.save
          #DZC se agrega la validación de la condición 'C', para ser coherente con el método continuar_flujo
          case @manifestacion_de_interes.resultado_pertinencia
          when "aceptada"
            
            actores_desde_campo = @manifestacion_de_interes.mapa_de_actores_data.blank? ? nil : @manifestacion_de_interes.mapa_de_actores_data.map{|i| i.transform_keys!(&:to_sym).to_h}
            MapaDeActor.actualiza_tablas_mapa_actores(actores_desde_campo, @flujo, @tarea_pendiente)
            @tarea_pendiente.pasar_a_siguiente_tarea 'A'
            #Cargar set de metas si se adherio a estandar o diagnostico.-
            if @manifestacion_de_interes.estandar_de_certificacion_id.present?
              @flujo.set_metas_acciones_by_estandar @manifestacion_de_interes.estandar_de_certificacion_id
            elsif @manifestacion_de_interes.diagnostico_id.present?
              set_metas_by_antiguo_acuerdo @manifestacion_de_interes.diagnostico_id, @flujo
            end
          when "solicita_condiciones", "realiza_observaciones", "solicita_condiciones_y_contiene_observaciones"
            @tarea_pendiente.pasar_a_siguiente_tarea 'B'
          when "no_aceptada"
            @tarea_pendiente.pasar_a_siguiente_tarea 'C'
          end
        end
        format.js { flash.now[:success] = 'Pertinencia-factibilidad enviada correctamente' 
          render js: "window.location='#{root_path}'"}
        format.html { redirect_to root_path, flash: {notice: 'Pertinencia-factibilidad enviada correctamente' }}
      else
        flash.now[:error] = "Antes de enviar debe completar todos los campos requeridos"
        # @responsables = Responsable.__personas_responsables(Rol::COORDINADOR, TipoInstrumento::ACUERDO_DE_PRODUCCION_LIMPIA)
        @responsables = Responsable.__personas_responsables(Rol.find_by(nombre: 'Coordinador').id, TipoInstrumento.find_by(nombre: 'Acuerdo de Producción Limpia').id)
        format.js { }
        format.html { render :pertinencia_factibilidad}
      end
    end
  end

  def responder_pertinencia_factibilidad #DZC APL-006
    unless @manifestacion_de_interes.secciones_observadas_pertinencia_factibilidad.nil?
      @total_de_errores_por_tab = @manifestacion_de_interes.secciones_observadas_pertinencia_factibilidad.map{|s| [s.to_sym, [""]]}.to_h
    end
  end

  def responder_cond_obs_pertinencia_factibilidad #DZC APL-006
    @manifestacion_de_interes.assign_attributes(manifestacion_pertinencia_params)
    unless @manifestacion_de_interes.secciones_observadas_pertinencia_factibilidad.nil?
      @total_de_errores_por_tab = @manifestacion_de_interes.secciones_observadas_pertinencia_factibilidad.map{|s| [s.to_sym, [""]]}.to_h
    end
    respond_to do |format|
      @manifestacion_de_interes.tarea_codigo = @tarea.codigo
      if @manifestacion_de_interes.valid?
        #DZC verifica la vigencia del plazo de 60 días corridos para evacuar las observaciones (condición 'C')
        if @manifestacion_de_interes.plazo_vigente? @manifestacion_de_interes.fecha_observaciones_pertinencia, 60
          @manifestacion_de_interes.save
          
          if manifestacion_pertinencia_params.key?(:update_respuesta_pertinencia) 
            if @tarea_pendiente.save && manifestacion_pertinencia_params[:update_respuesta_pertinencia] == "true"
              if @manifestacion_de_interes.resultado_pertinencia == "solicita_condiciones" || @manifestacion_de_interes.resultado_pertinencia == "solicita_condiciones_y_contiene_observaciones"
                case @manifestacion_de_interes.acepta_condiciones_pertinencia
                when true
                  @tarea_pendiente.pasar_a_siguiente_tarea 'A'
                when false
                  @tarea_pendiente.pasar_a_siguiente_tarea 'B'
                end
              else
                @tarea_pendiente.pasar_a_siguiente_tarea 'A'
              end
              format.js { flash.now[:success] = 'Respuesta a las observaciones sobre pertinencia y factibilidad enviada correctamente' 
                render js: "window.location='#{root_path}'"}
              format.html { redirect_to root_path, flash: {notice: 'Respuesta a las observaciones sobre pertinencia y factibilidad enviada correctamente' }}
            else #Toma este camino si solo se actualiza la manifestacion
              format.js { flash.now[:success] = 'Manifestación actualizada'}
              format.html { redirect_to responder_pertinencia_factibilidad_manifestacion_de_interes_path(@tarea_pendiente,@manifestacion_de_interes), flash: {notice: 'Manifestación actualizada' }}
            end
          end          
        else
          @tarea_pendiente.pasar_a_siguiente_tarea 'C' #DZC pasa a siguiente tarea ejecutando condición 'C' (pone término al flujo)
          format.js { flash.now[:error] = 'Ya se ha vencido el plazo para evacuar las observaciones sobre pertinencia y factibilidad. Se ha puesto término a la manifestación'; render js: "window.location='#{root_path}'" }
          format.html { redirect_to root_path(@tarea_pendiente, @manifestacion_de_interes), flash: {notice: 'Ya se ha vencido el plazo para evacuar las observaciones sobre pertinencia y factibilidad. Se ha puesto término a la manifestación' }}
        end
      else
        flash.now[:error] = "Antes de enviar debe completar todos los campos requeridos"
        # @responsables = Responsable.__personas_responsables(Rol::COORDINADOR, TipoInstrumento::ACUERDO_DE_PRODUCCION_LIMPIA)
        @responsables = Responsable.__personas_responsables(Rol.find_by(nombre: 'Coordinador').id, TipoInstrumento.find_by(nombre: 'Acuerdo de Producción Limpia').id)
        @total_de_errores_por_tab = [] if @manifestacion_de_interes.secciones_observadas_pertinencia_factibilidad.nil?
        @total_de_errores_por_tab[:"pertinencia-factibilidad"] = [""]
        format.js { }
        format.html { render :responder_pertinencia_factibilidad}
      end
    end
  end

  def usuario_entregables #DZC APL-008
  end

  def guardar_usuario_entregables #DZC APL-008
    @manifestacion_de_interes.assign_attributes(manifestacion_usuario_entregables_params)
    @manifestacion_de_interes.temporal = true
    @manifestacion_de_interes.update_usuario_entregables = true
    respond_to do |format|
      
      if @manifestacion_de_interes.valid?
        @manifestacion_de_interes.tarea_codigo = @tarea.codigo
        @manifestacion_de_interes.save
        mapa = MapaDeActor.find_or_create_by({
          flujo_id: @tarea_pendiente.flujo_id,
          rol_id: Rol::RESPONSABLE_ENTREGABLES,
          # rol_id: Rol.find_by(nombre: 'Responsable Entregables').id,
          persona_id: manifestacion_usuario_entregables_params[:usuario_entregables_id]
        })
        @manifestacion_de_interes.temporal = true
        @manifestacion_de_interes.update(mapa_de_actores_data: nil) #DZC resetea el valor del campo, para que se contruyan archivos desde las tablas
        @tarea_pendiente.pasar_a_siguiente_tarea 'A', {primera_ejecucion: true}
        format.js { flash.now[:success] = 'Usuario encargado de entregables asignado correctamente' }
        format.html { redirect_to root_path, flash: {notice: 'Usuario encargado de entregables asignado correctamente' }}
      else
        flash.now[:error] = "Antes de enviar debe completar todos los campos requeridos"
        format.js { }
        format.html { render :usuario_entregables}
      end
    end
  end

  def cargar_actualizar_entregable_diagnostico #DZC APL-013
    if params[:tab_metas].present?
      @tab_metas = params[:tab_metas]
    end
    # DZC 2018-10-26 16:11:53 se modifica lectura de datos
    @actores_desde_campo = @manifestacion_de_interes.mapa_de_actores_data.blank? ? nil : @manifestacion_de_interes.mapa_de_actores_data.map{|i| i.transform_keys!(&:to_sym).to_h}
    @actores_desde_tablas = MapaDeActor.construye_data_para_apl(@flujo)
    if @tarea_pendiente.data == {primera_ejecucion: true} || @tarea.codigo =='APL-001'
      @actores = MapaDeActor.adecua_actores_para_vista(@actores_desde_tablas)
    else
      @actores = (@actores_desde_campo.blank? ? MapaDeActor.adecua_actores_para_vista(@actores_desde_tablas) : MapaDeActor.adecua_actores_para_vista(@actores_desde_campo))
    end

    @manifestacion_de_interes.accion_en_mapa_de_actores = :actualizacion
    @manifestacion_de_interes.accion_en_documento_diagnostico = :actualizacion
    @manifestacion_de_interes.accion_en_set_metas_accion = :actualizacion
    @manifestacion_de_interes.mapa_de_actores_correctamente_construido = true
    @manifestacion_de_interes.temporal = true
    unless @manifestacion_de_interes.comentarios_y_observaciones_actualizacion_mapa_de_actores.blank?
      comentarios = @manifestacion_de_interes.comentarios_y_observaciones_actualizacion_mapa_de_actores.last
      @actores_con_observaciones = comentarios[:actores_con_observaciones]
    end
    @comentarios = @manifestacion_de_interes.comentarios_diagnostico_ordenados
    @manifestacion_de_interes.setear_documento_diagnosticos
    @set_metas_acciones = SetMetasAccion.de_la_manifestacion_de_interes_(@manifestacion_de_interes.id)
    @set_metas_accion = SetMetasAccion.new
    if params[:tab_metas].present? # DZC 2018-11-05 09:50:57 permite focalizar la vista en la pestaña set metas y acciones
      @tab_metas = params[:tab_metas]
    end 
    @informe=InformeAcuerdo.find_by(manifestacion_de_interes_id: @manifestacion_de_interes.id)
    unless @manifestacion_de_interes.comentarios_y_observaciones_set_metas_acciones.blank?
      comentarios = @manifestacion_de_interes.comentarios_y_observaciones_set_metas_acciones.last
      @propuestas_con_observaciones = comentarios[:requiere_correcciones]
    end
  end

  def revisar_entregable_diagnostico #DZC APL-014
   #DZC convierto el hash con string keys a hash_with_indiferent_access, y de vuelta a hash con key simbólicas, o nil, según corresponda
   actores_desde_campo = @manifestacion_de_interes.mapa_de_actores_data.blank? ? nil : @manifestacion_de_interes.mapa_de_actores_data.map{|i| i.transform_keys!(&:to_sym).to_h}
   @actores = (!actores_desde_campo.nil? ? MapaDeActor.adecua_actores_para_vista(actores_desde_campo) : {})
    # if @manifestacion_de_interes.mapa_de_actores_data.blank?
    #   @actores = []
    # else
    #   @actores = @manifestacion_de_interes.mapa_de_actores_data
    # end
    @manifestacion_de_interes.accion_en_mapa_de_actores = :revision
    @manifestacion_de_interes.accion_en_documento_diagnostico = :revision
    @manifestacion_de_interes.accion_en_set_metas_accion = :revision
    @manifestacion_de_interes.mapa_de_actores_correctamente_construido = true
    @manifestacion_de_interes.temporal = true
    unless @manifestacion_de_interes.comentarios_y_observaciones_actualizacion_mapa_de_actores.blank?
      comentarios = @manifestacion_de_interes.comentarios_y_observaciones_actualizacion_mapa_de_actores.last
      @actores_con_observaciones = comentarios[:actores_con_observaciones]
      @manifestacion_de_interes.comentarios_y_observaciones_actualizacion_mapa_de_actores = nil
    end
    
    @comentarios = @manifestacion_de_interes.comentarios_diagnostico_ordenados
    @manifestacion_de_interes.setear_documento_diagnosticos
    # DZC 2018-10-09 14:37:00 se borran los comentarios anteriores
    @manifestacion_de_interes.comentarios_y_observaciones_documento_diagnosticos = nil
    @set_metas_acciones = SetMetasAccion.de_la_manifestacion_de_interes_(@manifestacion_de_interes.id)
    @set_metas_accion = SetMetasAccion.new
    unless @manifestacion_de_interes.comentarios_y_observaciones_set_metas_acciones.blank?
      comentarios = @manifestacion_de_interes.comentarios_y_observaciones_set_metas_acciones.last
      @propuestas_con_observaciones = comentarios[:requiere_correcciones]
      @manifestacion_de_interes.comentarios_y_observaciones_set_metas_acciones = nil
    end
    
  end

  def termina_etapa_diagnostico #DZC APL-014 TERMINA TODAS LAS TAREAS DESDE APL-014 HACIA ATRAS
    respond_to do |format|
      
      #DZC agrega el comentario sobre el término al campo respectivo de la manifestación
      @manifestacion = @flujo.manifestacion_de_interes
      @manifestacion.observaciones_documentos_diagnostico = params[:tarea_pendiente][:observaciones_documentos_diagnostico] #DZC se agregan los parametros de esta forma para agregar el id de la manifestación en la URL
      @manifestacion.temporal = true

      # DZC 2018-10-11 13:14:21 se modifica el método para considerar como aprobada la información ingresada en las tres pestañas de la tarea APL-013
      # DZC 2018-10-11 13:15:06 Mapa de actores:
      comentarios_anteriores = @manifestacion.comentarios_y_observaciones_actualizacion_mapa_de_actores.blank? ? [] : @manifestacion.comentarios_y_observaciones_actualizacion_mapa_de_actores
      comentarios_anteriores << {
          datetime: DateTime.now,
          user: current_user.nombre_completo,
          actores_con_observaciones: nil,
          texto: "Mapa de actores aprobado por #{current_user.nombre_completo}"
        }
      @manifestacion.comentarios_y_observaciones_actualizacion_mapa_de_actores = comentarios_anteriores

      # DZC 2018-10-11 13:15:22 Documentos de diagnóstico:
      @manifestacion.documento_diagnosticos.update_all(requiere_correcciones: false)

      # DZC 2018-10-11 13:16:27 Set de metas y acciones:
      comentarios_anteriores = @manifestacion.comentarios_y_observaciones_set_metas_acciones.blank? ? [] : @manifestacion.comentarios_y_observaciones_set_metas_acciones
      comentarios_anteriores << {
        datetime: DateTime.now,
        # user: current_user.nombre_completo(),
        user: current_user.nombre_completo,
        requiere_correcciones: nil,
        texto: "Set de metas y acciones aprobado por #{current_user.nombre_completo}"
      }
      @manifestacion.diagnostico_fecha_termino = Time.now.utc      
      @manifestacion.tarea_codigo = @tarea.codigo
      # DZC 2018-10-30 10:23:33 se agrega poblamiento de tablas en virtud del contenido del campo mapa_de_actores_data
      
      if @manifestacion.save && @manifestacion.mapa_de_actores_data.present?
        actores_desde_campo = @manifestacion.mapa_de_actores_data.map{|i| i.transform_keys!(&:to_sym).to_h}
        MapaDeActor.actualiza_tablas_mapa_actores(actores_desde_campo, @flujo, @tarea_pendiente)
        @manifestacion.update(mapa_de_actores_data: nil)
      end
      
      #DZC da por terminadas las tareas APL-011, APL-012, APL-013
      TareaPendiente.where(flujo_id: @flujo.id).includes([:tarea]).where({"tareas.codigo" => [Tarea::COD_APL_011.to_s, Tarea::COD_APL_012.to_s, Tarea::COD_APL_013.to_s]}).update(estado_tarea_pendiente_id: 2)
      # @tarea_pendiente.pasar_a_siguiente_tarea 'A'
      continua_flujo_segun_tipo_tarea
      format.js {
        flash[:success] = 'Se puso término a la etapa de diagnóstico'; render js: "window.location='#{root_path}'" 
      }
      format.html { redirect_to root_path, flash: {notice: 'Se puso término a la etapa de diagnóstico' }}
    end
  end

  def termina_etapa_negociacion #DZC APL-016 TERMINA TODAS LAS TAREAS DESDE APL-016 HACIA ATRAS
    respond_to do |format|
      #DZC agrega el comentario sobre el término al campo respectivo de la manifestación
      @manifestacion = @flujo.manifestacion_de_interes
      @manifestacion.temporal = true #DZC eliminar cuando se pase a produccion
      @manifestacion.update(manifestacion_terminar_negociacion_params)
      
      unless @manifestacion.comentarios_y_observaciones_negociacion_acuerdo.blank?
        #DZC da por terminadas las tareas APL-01, APL-012, APL-013
        TareaPendiente.where(flujo_id: @flujo.id).includes([:tarea]).where({"tareas.codigo" => [Tarea::COD_APL_017.to_s, Tarea::COD_APL_018.to_s]}).update(estado_tarea_pendiente_id: 2)
        # @tarea_pendiente.pasar_a_siguiente_tarea 'B'
        continua_flujo_segun_tipo_tarea
        format.js { flash.now[:success] = 'Se puso término a la etapa de negociación'; render js: "window.location='#{root_path}'" }
        format.html { redirect_to root_path, flash: {notice: 'Se puso término a la etapa de negociación' }}
      else
        format.js { 
          flash[:error] = 'Por favor ingrese los comentarios que justifican el termino de la etapa de negociación.'
          render js: "window.location='#{tarea_pendiente_convocatorias_path(@tarea_pendiente)}'" }
        format.html { redirect_to tarea_pendiente_convocatorias_path(@tarea_pendiente), flash: {error: 'Por favor ingrese los comentarios que justifican el termino de la etapa de negociación' }}
      end
    end
  end

  def evaluacion_negociacion #DZC APL-019 Encuesta y Set de metas y acciones
    @manifestacion_de_interes.temporal = true
    @encuesta = Encuesta.find(params[:encuesta_id])
    if @tarea_pendiente.blank? || @tarea_pendiente.user_id != current_user.id || @tarea_pendiente.no_esta_pendiente?
      encuesta_no_encontrada
    else
      @desactivado = (EncuestaUserRespuesta.where(flujo_id: @flujo.id, encuesta_id: @encuesta.id, user_id: current_user.id).size >= @encuesta.encuesta_preguntas.where(obligatorio: true).size)
      @encuesta_user_respuesta = EncuestaUserRespuesta.new
    end
    @manifestacion_de_interes.accion_en_set_metas_accion = :observacion
    @set_metas_acciones = SetMetasAccion.de_la_manifestacion_de_interes_(@manifestacion_de_interes.id)
    # DZC 2018-11-02 18:01:16 se agrega para posicionar la vista en la pestaña "set metas y acciones"
    if params[:tab_metas].present?
      @tab_metas = params[:tab_metas]
    end
    # @set_metas_accion = SetMetasAccion.new
    # unless @manifestacion_de_interes.comentarios_y_observaciones_set_metas_acciones.blank?
    #   comentarios = @manifestacion_de_interes.comentarios_y_observaciones_set_metas_acciones.last
    #   @propuestas_con_observaciones = comentarios[:requiere_correcciones]
    # end

  end

  def actualizar_acuerdos_actores #DZC APL-020
    actores_desde_tablas = MapaDeActor.construye_data_para_apl (@flujo)
    @actores = (!MapaDeActor.adecua_actores_para_vista(actores_desde_tablas).blank? ? MapaDeActor.adecua_actores_para_vista(actores_desde_tablas) : [])#DZC se cambia la lectura de actores a la tabla
    @manifestacion_de_interes.temporal = true 
    @manifestacion_de_interes.accion_en_mapa_de_actores = :revision #DZC consultar con Stefano y/o cambiar a :actualizacion
    @manifestacion_de_interes.accion_en_set_metas_accion = :respuesta
    @set_metas_acciones = SetMetasAccion.de_la_manifestacion_de_interes_(@manifestacion_de_interes.id)
    # DZC 2018-11-02 18:54:37 se agrega para posicionar la vista en la pestaña "set metas y acciones"   
    if params[:tab_metas].present?
      @tab_metas = params[:tab_metas]
    end
    # @set_metas_accion = SetMetasAccion.new
    unless @manifestacion_de_interes.comentarios_y_observaciones_actualizacion_mapa_de_actores.blank?
      comentarios = @manifestacion_de_interes.comentarios_y_observaciones_actualizacion_mapa_de_actores.last
      @actores_con_observaciones = comentarios[:actores_con_observaciones]
    end
    # unless @manifestacion_de_interes.comentarios_y_observaciones_set_metas_acciones.blank?
    #   comentarios = @manifestacion_de_interes.comentarios_y_observaciones_set_metas_acciones.last
    #   @propuestas_con_observaciones = comentarios[:requiere_correcciones]
    # end
  end

  def termina_actualizacion_actores_resuelve_comentarios_propuestas #DZC APL-020 TERMINA TAREA APL-020
    respond_to do |format|
      continua_flujo_segun_tipo_tarea# 'A', {primera_ejecucion: true}
      format.js { flash.now[:success] = 'Se terminó actualización de mapa de actores y resolución de comentarios en propuestas de acuerdo'; render js: "window.location='#{root_path}'" }
      format.html { redirect_to root_path, flash: {notice: 'Se terminó actualización de mapa de actores y resolución de comentarios en propuestas de acuerdo' }}
    end
  end

  def terminar_acuerdo #DZC APL-023 TERMINA TODAS LAS TAREAS DESDE APL-023 HACIA ATRAS
    respond_to do |format|
      
      #DZC agrega el comentario sobre el término al campo respectivo de la manifestación
      @manifestacion = @flujo.manifestacion_de_interes
      @manifestacion.temporal = true #DZC eliminar cuando se pase a produccion
      @manifestacion.update(manifestacion_terminar_acuerdo_params)

      #DZC da por terminadas TODAS las tareas tareas del flujo
      TareaPendiente.where(flujo_id: @flujo.id).includes([:tarea]).all.update(estado_tarea_pendiente_id: 2)
      @flujo.update(terminado: true) #DZC termina el flujo 
      format.js { flash.now[:success] = 'Se puso término al acuerdo'; render js: "window.location='#{root_path}'" }
      format.html { redirect_to root_path, flash: {notice: 'Se puso término al acuerdo' }}
    end
  end

  def google_map_kml
    @content = nil#{}"<?xml version='1.0' encoding='UTF-8'?><kml xmlns='http://www.opengis.net/kml/2.2'><Document></Document></kml>"
    manifestacion_de_interes = ManifestacionDeInteres.find(params[:id]) rescue nil
    unless manifestacion_de_interes.blank?

      if params[:file] == 'area-influencia-proyecto' && ! manifestacion_de_interes.area_influencia_proyecto_data.blank?
        @content = manifestacion_de_interes.area_influencia_proyecto_data.file.read
      elsif params[:file] == 'alternativas-instalacion' && ! manifestacion_de_interes.alternativas_instalacion_data.blank?
        @content = manifestacion_de_interes.alternativas_instalacion_data.file.read
      end
    end
    unless false
      send_data @content, type: 'application/vnd.google-earth.kml+xml', charset: "iso-8859-1", filename: "archivo_google_map.kml"
    else
      render layout: false
      respond_to do |format|
        format.html
      end
    end
  end

  def descargable
    director = Variable.where(nombre: :nombre_director_ascc).first
    descargable = DescargableTarea.find(params[:descargable_tarea_id])
    mdi = @manifestacion_de_interes
    metodos = {
      "[campo_acuerdo]": mdi.nombre_proyecto.blank? ? '--' : mdi.nombre_proyecto,
      "[nombre_director_ascc]": director.blank? ? '--' : director[:valor],
      "[fecha_hoy]": (l(Date.today,format: "%A, %d de %B %Y")),
      "[representante_entidad_cogestora]": mdi.nombre_representante_para_acuerdo.blank? ? '--' : mdi.nombre_representante_para_acuerdo, 
      "[nombre_entidad_cogestora]": mdi.institucion_gestora_acuerdo.blank? ? '--' : mdi.institucion_gestora_acuerdo, 
    }
    file = descargable.file(metodos)
    send_data file[:content], type: "application/#{file[:format]}", charset: "iso-8859-1", filename: file[:filename]
  end

  def descargar_mapa_de_actores 
    ruta = "#{Rails.root}/public/uploads/manifestacion_de_interes/mapa_de_actores_archivo/#{@manifestacion_de_interes.id}/"
    ruta += ""
    send_data File.open("#{Rails.root}/files/mapa_de_actores.xlsx").read, type: 'application/xslx', charset: "iso-8859-1", filename: "mapa_de_actores.xlsx"
  end
 
  def firma
    @firmantes = MapaDeActor.where(flujo_id: @tarea_pendiente.flujo_id, rol_id: Rol::FIRMANTE).includes(persona: :user).all
    @descargables = @tarea_pendiente.get_descargables
  end

  def actualizar_firma
    @manifestacion_de_interes.assign_attributes(manifestacion_firma_params)
    @firmantes = MapaDeActor.where(flujo_id: @tarea_pendiente.flujo_id, rol_id: Rol::FIRMANTE).includes(persona: :user).all
    @descargables = @tarea_pendiente.get_descargables
    respond_to do |format|
      if @manifestacion_de_interes.valid?
        @manifestacion_de_interes.tarea_codigo = @tarea.codigo
        @manifestacion_de_interes.save
        #enviar correo?

        format.js { flash.now[:success] = 'Convocatoria de firma enviada correctamente' }
        format.html { redirect_to firma_manifestacion_de_interes_path(@tarea_pendiente,@manifestacion_de_interes), flash: {notice: 'Convocatoria de firma enviada correctamente' }}
      else
        format.js { }
        format.html { redirect_to firma_manifestacion_de_interes_path(@tarea_pendiente,@manifestacion_de_interes), flash: {error: 'Problema al enviar convocatoria de firma' }}
      end
    end
  end

  def carga_auditoria #DZC APL-032 method: :get 
  end

  def enviar_carga_auditoria #DZC APL-032 method: :patch
    @manifestacion_de_interes.assign_attributes(manifestacion_carga_audit_params)
    @descargables = @tarea_pendiente.get_descargables
    respond_to do |format|
      if @manifestacion_de_interes.valid?
        @manifestacion_de_interes.tarea_codigo = @tarea.codigo
        @manifestacion_de_interes.save

        format.js { flash.now[:success] = 'Carga de auditoría enviada correctamente' }
        format.html { redirect_to carga_auditoria_manifestacion_de_interes_path(@tarea_pendiente,@manifestacion_de_interes), flash: {notice: 'Carga de auditoría enviada correctamente' }}
      else
        format.js { }
        format.html { redirect_to carga_auditoria_manifestacion_de_interes_path(@tarea_pendiente,@manifestacion_de_interes), flash: {error: 'Problema al enviar carga de auditoría' }}
      end
    end
  end

  def continua_flujo_segun_tipo_tarea #DZC generalización de condiciones de continuación de flujo
    case @tarea.codigo
    when Tarea::COD_APL_001
      @tarea_pendiente.pasar_a_siguiente_tarea
    when Tarea::COD_APL_002
      @manifestacion_de_interes.temporal = true
      @manifestacion_de_interes.update(mapa_de_actores_data: nil) #DZC resetea el valor del campo, para que se contruyan archivos desde las tablas
      @tarea_pendiente.pasar_a_siguiente_tarea 'A'
    when Tarea::COD_APL_003
      case @manifestacion_de_interes.resultado_admisibilidad
      when "aceptado"
        @tarea_pendiente.pasar_a_siguiente_tarea 'A'
      when "en_observación"
        @tarea_pendiente.pasar_a_siguiente_tarea 'B'
      when "rechazado"
        #DZC se agrega la validación de la condición 'C', para ser coherente con el método continuar_flujo
        @tarea_pendiente.pasar_a_siguiente_tarea 'C'
      end
    when Tarea::COD_APL_014 # corresponde a la pestaña "Cargar documentos diagnóstico" de la APL-014
      @tarea_pendiente.pasar_a_siguiente_tarea 'A', {primera_ejecucion: true}
    when Tarea::COD_APL_016
      @tarea_pendiente.pasar_a_siguiente_tarea 'B'
    when Tarea::COD_APL_020
      @tarea_pendiente.pasar_a_siguiente_tarea 'A'
    end
  end

  private

    def set_tarea_pendiente
      @tarea_pendiente = TareaPendiente.includes([:flujo]).find(params[:tarea_pendiente_id])
      
      autorizado? @tarea_pendiente
      @tarea = @tarea_pendiente.tarea
    end
    #DZC define el flujo y tipo_instrumento, junto con la manifestación o el proyecto según corresponda, para efecto de completar datos. El id de la manifestación se obtiene del flujo correspondiente a la tarea pendiente.
    def set_flujo
      @flujo = @tarea_pendiente.flujo
      @tipo_instrumento=@flujo.tipo_instrumento
    end

    def set_manifestacion_de_interes
      # @manifestacion_de_interes = ManifestacionDeInteres.find(params[:id])
      @manifestacion_de_interes = ManifestacionDeInteres.find(@flujo.manifestacion_de_interes_id)
      @manifestacion_de_interes.current_user = current_user
      @manifestacion_de_interes.update(tarea_codigo: @tarea.codigo)
      checked = @manifestacion_de_interes.set_checked
      @rpc_checked = checked[:rpc_checked]
      @actecos_checked = checked[:actecos_checked]
      @descargables = @tarea_pendiente.get_descargables
      @area_influencia_proyecto_kml   = @manifestacion_de_interes.area_influencia_proyecto_archivo.blank? ? nil : google_map_kml_url(@manifestacion_de_interes,'area-influencia-proyecto')
      @alternativas_instalacion_kml   = @manifestacion_de_interes.alternativas_instalacion_archivo.blank? ? nil : google_map_kml_url(@manifestacion_de_interes,'alternativas-instalacion')
      @area_influencia_proyecto_data  = @manifestacion_de_interes.area_influencia_proyecto_data.blank? ? nil :  @manifestacion_de_interes.area_influencia_proyecto_data
      @alternativas_instalacion_data  = @manifestacion_de_interes.alternativas_instalacion_data.blank? ? nil :  @manifestacion_de_interes.alternativas_instalacion_data
    end

    def set_archivo_mapa_actores
      @manifestacion_de_interes.update(tarea_codigo: Tarea::COD_APL_001)
      MapaDeActor.find_or_create_by(
          flujo_id: @flujo.id,
          persona_id: current_user.personas.first.id,
          rol_id: 1
      )
    end

    def set_contribuyentes
      # DZC 2018-10-10 16:42:42 se agrega contribuyente del proponente
      @contribuyente = Contribuyente.new
      personas_proponentes = current_user.personas & Responsable.responsables_por_rol(Rol::PROPONENTE)
      # DZC 2018-11-19 10:27:27 se modifica para que no hayan contribuyentes precargados
      @contribuyentes_del_proponente = Contribuyente.where(id: personas_proponentes.pluck(:contribuyente_id))

      #DZC 2018-10-10 16:44:00 TODO: revisar impacto y eliminar si corresponde
    	@contribuyentes = Contribuyente.where(id: @personas.map{|m|m[:contribuyente_id]}).all
    end

    def set_tipo_instrumentos
      tiid = TipoInstrumento::ACUERDO_DE_PRODUCCION_LIMPIA
      # DZC 2018-11-16 15:30:03 se modifica para excluir el tipo de acuerdo padre de la selección
      @tipo_instrumentos = TipoInstrumento.where("tipo_instrumento_id = (?)",tiid).all
      # @tipo_instrumentos = TipoInstrumento.where("tipo_instrumento_id = (?) OR id = (?)",tiid,tiid).all
      
    end


    def manifestacion_params
      parameters = params.require(:manifestacion_de_interes).permit(
      	:current_tab,:tipo_instrumento_id,:descripcion_acuerdo,:proponente,:contribuyente_id,:institucion_proponente,:institucion_gestora_acuerdo,:rut_institucion_gestora_acuerdo,:direccion_institucion_gestora_acuerdo,:lugar_institucion_gestora_acuerdo,
        :ubicacion_exacta,:tipo_contribuyente_de_institucion_gestora,:numero_de_socios_institucion_gestora,:experiencia_en_gestion_de_proyectos,:fecha_creacion_institucion,:nombre_representante_para_acuerdo,:rut_representante_para_acuerdo,
        :sexo_representante_para_acuerdo,:telefono_representante_para_acuerdo,:email_representante_para_acuerdo,:carta_de_interes_institucion_gestora_firmada,:carta_de_interes_institucion_gestora_firmada_cache,:elegir_territorios,:representacion_en_mapa_selecciones,
        :caracterizacion_sector_territorio,:principales_actores,:mapa_de_actores_archivo,:mapa_de_actores_archivo_cache,:numero_empresas,:porcentaje_mipymes,:produccion,:ventas,:porcentaje_exportaciones,:principales_mercados,:numero_trabajadores,:vulnerabilidad_al_cambio_climatico_del_sector,
        :principales_impactos_socioambientales_del_sector,:principales_problemas_y_desafios,:principales_conflictos,:estudios_sectoriales_territoriales_relevantes,:estudios_sectoriales_territoriales_relevantes_cache,:otro_contexto_sector,:nombre_proyecto,:descripcion_proyecto,
        :justificacion_proyecto,:area_influencia_proyecto_archivo,:area_influencia_proyecto_archivo_cache,:area_influencia_proyecto_data,:area_influencia_proyecto_archivo,:area_influencia_proyecto_archivo_cache,:alternativas_instalacion_archivo,
        :alternativas_instalacion_archivo_cache,:alternativas_instalacion_data,:monto_inversion,:tecnologia,:estado_proyecto,:estudio_de_mercado,:estudio_de_mercado_cache,:anteproyecto,:anteproyecto_cache,:gantt_proyecto,:gantt_proyecto_cache,:operador,:otros_proyectos_en_territorios_cercanos,:otros_estudios,
        :otros_estudios_cache,:otro_datos_proyecto,:nombre_acuerdo,:motivacion_y_objetivos,:equipo_de_trabajo_comprometido,:organigrama,:organigrama_cache,:patrocinadores,:monto_total_comprometido,:otros_recursos_comprometidos,:carta_de_apoyo_y_compromiso,:carta_de_apoyo_y_compromiso_cache,
        :numero_participantes,:lista_participantes,:priorizacion,:otras_iniciativas_relacionadas_en_ejecucion,:diagnostico_id,:estandar_de_certificacion_id,:otros_objetivos_acuerdo,:otros_estudios_relevantes,:otros_estudios_relevantes_cache,:coordernadas_territorios,:temporal, :current_user, :representante_institucion_para_solicitud_id, :proponente_institucion_id,
        sectores_economicos:{},territorios_regiones:{},territorios_provincias:{},territorios_comunas:{},
      )
      #Permite parsear el formato de nùmero para que el motor de base datos pueda almacenar nùmeros con punto (ex. 1.000). al momento se realiza para los montos de tipo moneda.-
      parameters[:monto_total_comprometido] = parameters[:monto_total_comprometido].gsub('.','')
      parameters[:ventas] = parameters[:ventas].gsub('.','')
      parameters[:monto_inversion] = parameters[:monto_inversion].gsub('.','')
      parameters
    end

    def manifestacion_revisor_params
      params.require(:manifestacion_de_interes).permit(
        :revisor_id,
        :comentario_jefe_de_linea,
        :temporal
      )
    end

    def manifestacion_usuario_entregables_params
      params.require(:manifestacion_de_interes).permit(
        :usuario_entregables_id,
        :archivo_usuario_entregables,
        :usuario_entregables_comentario,
        :usuario_entregables_otros
        # :archivo_usuario_entregables,
        # :update_usuario_entregables,
        # :temporal
      )
    end

    def manifestacion_admisibilidad_params #DZC se modifica para agregar fecha de las observaciones y posteriormente comprobar cumplimiento plazo para evacuar dichas observaciones
      parametros=params.require(:manifestacion_de_interes).permit(
        :resultado_admisibilidad,
        :observaciones_admisibilidad,
        :temporal,
        :update_admisibilidad,
        secciones_observadas_admisibilidad: []
      )
      if @manifestacion_de_interes.fecha_observaciones_admisibilidad.nil?
        parametros[:fecha_observaciones_admisibilidad]=Time.now.utc
      end
      parametros
    end

    def manifestacion_obs_admisibilidad_params
      parametros=params.require(:manifestacion_de_interes).permit(
        :current_tab,:tipo_instrumento_id,:descripcion_acuerdo,:proponente,:contribuyente_id,:institucion_proponente,:institucion_gestora_acuerdo,:rut_institucion_gestora_acuerdo,:direccion_institucion_gestora_acuerdo,:lugar_institucion_gestora_acuerdo,
        :ubicacion_exacta,:tipo_contribuyente_de_institucion_gestora,:numero_de_socios_institucion_gestora,:experiencia_en_gestion_de_proyectos,:fecha_creacion_institucion,:nombre_representante_para_acuerdo,:rut_representante_para_acuerdo,
        :sexo_representante_para_acuerdo,:telefono_representante_para_acuerdo,:email_representante_para_acuerdo,:carta_de_interes_institucion_gestora_firmada,:carta_de_interes_institucion_gestora_firmada_cache,:elegir_territorios,:representacion_en_mapa_selecciones,
        :caracterizacion_sector_territorio,:principales_actores,:mapa_de_actores_archivo,:mapa_de_actores_archivo_cache,:numero_empresas,:porcentaje_mipymes,:produccion,:ventas,:porcentaje_exportaciones,:principales_mercados,:numero_trabajadores,:vulnerabilidad_al_cambio_climatico_del_sector,
        :principales_impactos_socioambientales_del_sector,:principales_problemas_y_desafios,:principales_conflictos,:estudios_sectoriales_territoriales_relevantes,:estudios_sectoriales_territoriales_relevantes_cache,:otro_contexto_sector,:nombre_proyecto,:descripcion_proyecto,
        :justificacion_proyecto,:area_influencia_proyecto_archivo,:area_influencia_proyecto_archivo_cache,:area_influencia_proyecto_data,:area_influencia_proyecto_archivo,:area_influencia_proyecto_archivo_cache,:alternativas_instalacion_archivo,
        :alternativas_instalacion_archivo_cache,:alternativas_instalacion_data,:monto_inversion,:tecnologia,:estado_proyecto,:estudio_de_mercado,:estudio_de_mercado_cache,:anteproyecto,:anteproyecto_cache,:gantt_proyecto,:gantt_proyecto_cache,:operador,:otros_proyectos_en_territorios_cercanos,:otros_estudios,
        :otros_estudios_cache,:otro_datos_proyecto,:nombre_acuerdo,:motivacion_y_objetivos,:equipo_de_trabajo_comprometido,:organigrama,:organigrama_cache,:patrocinadores,:monto_total_comprometido,:otros_recursos_comprometidos,:carta_de_apoyo_y_compromiso,:carta_de_apoyo_y_compromiso_cache,
        :numero_participantes,:lista_participantes,:priorizacion,:otras_iniciativas_relacionadas_en_ejecucion,:diagnostico_id,:estandar_de_certificacion_id,:otros_objetivos_acuerdo,:otros_estudios_relevantes,:otros_estudios_relevantes_cache,:coordernadas_territorios,:temporal, :current_user, :representante_institucion_para_solicitud_id, :proponente_institucion_id,
        :respuesta_observaciones_admisibilidad,
        :archivo_admisibilidad,
        :update_obs_admisibilidad,
        sectores_economicos:{},territorios_regiones:{},territorios_provincias:{},territorios_comunas:{},
      )
      #Permite parsear el formato de nùmero para que el motor de base datos pueda almacenar nùmeros con punto (ex. 1.000). al momento se realiza para los montos de tipo moneda.-
      parametros[:monto_total_comprometido] = parametros[:monto_total_comprometido].gsub('.','')
      parametros[:ventas] = parametros[:ventas].gsub('.','')
      parametros[:monto_inversion] = parametros[:monto_inversion].gsub('.','')
      parametros
    end

    def manifestacion_pertinencia_params #DZC se modifica para agregar fecha de las observaciones y posteriormente comprobar cumplimiento plazo para evacuar dichas observaciones
      parametros=params.require(:manifestacion_de_interes).permit(
        :current_tab,:tipo_instrumento_id,:descripcion_acuerdo,:proponente,:contribuyente_id,:institucion_proponente,:institucion_gestora_acuerdo,:rut_institucion_gestora_acuerdo,:direccion_institucion_gestora_acuerdo,:lugar_institucion_gestora_acuerdo,
        :ubicacion_exacta,:tipo_contribuyente_de_institucion_gestora,:numero_de_socios_institucion_gestora,:experiencia_en_gestion_de_proyectos,:fecha_creacion_institucion,:nombre_representante_para_acuerdo,:rut_representante_para_acuerdo,
        :sexo_representante_para_acuerdo,:telefono_representante_para_acuerdo,:email_representante_para_acuerdo,:carta_de_interes_institucion_gestora_firmada,:carta_de_interes_institucion_gestora_firmada_cache,:elegir_territorios,:representacion_en_mapa_selecciones,
        :caracterizacion_sector_territorio,:principales_actores,:mapa_de_actores_archivo,:mapa_de_actores_archivo_cache,:numero_empresas,:porcentaje_mipymes,:produccion,:ventas,:porcentaje_exportaciones,:principales_mercados,:numero_trabajadores,:vulnerabilidad_al_cambio_climatico_del_sector,
        :principales_impactos_socioambientales_del_sector,:principales_problemas_y_desafios,:principales_conflictos,:estudios_sectoriales_territoriales_relevantes,:estudios_sectoriales_territoriales_relevantes_cache,:otro_contexto_sector,:nombre_proyecto,:descripcion_proyecto,
        :justificacion_proyecto,:area_influencia_proyecto_archivo,:area_influencia_proyecto_archivo_cache,:area_influencia_proyecto_data,:area_influencia_proyecto_archivo,:area_influencia_proyecto_archivo_cache,:alternativas_instalacion_archivo,
        :alternativas_instalacion_archivo_cache,:alternativas_instalacion_data,:monto_inversion,:tecnologia,:estado_proyecto,:estudio_de_mercado,:estudio_de_mercado_cache,:anteproyecto,:anteproyecto_cache,:gantt_proyecto,:gantt_proyecto_cache,:operador,:otros_proyectos_en_territorios_cercanos,:otros_estudios,
        :otros_estudios_cache,:otro_datos_proyecto,:nombre_acuerdo,:motivacion_y_objetivos,:equipo_de_trabajo_comprometido,:organigrama,:organigrama_cache,:patrocinadores,:monto_total_comprometido,:otros_recursos_comprometidos,:carta_de_apoyo_y_compromiso,:carta_de_apoyo_y_compromiso_cache,
        :numero_participantes,:lista_participantes,:priorizacion,:otras_iniciativas_relacionadas_en_ejecucion,:diagnostico_id,:estandar_de_certificacion_id,:otros_objetivos_acuerdo,:otros_estudios_relevantes,:otros_estudios_relevantes_cache,:coordernadas_territorios,:temporal, :current_user, :representante_institucion_para_solicitud_id, :proponente_institucion_id,
        :resultado_pertinencia,
        :observaciones_pertinencia_factibilidad,
        :compromiso_pertinencia_factibilidad,
        :archivo_pertinencia_factibilidad,
        :coordinador_subtipo_instrumento_id,
        :respuesta_resultado_pertinencia,
        :acepta_condiciones_pertinencia,
        :respuesta_observaciones_pertinencia_factibilidad,
        :respuesta_otros_pertinencia_factibilidad,
        :archivo_respuesta_pertinencia_factibilidad,
        :update_respuesta_pertinencia,
        :update_pertinencia,
        sectores_economicos:{},territorios_regiones:{},territorios_provincias:{},territorios_comunas:{},
        secciones_observadas_pertinencia_factibilidad: []
      )
      if @manifestacion_de_interes.fecha_observaciones_pertinencia.nil?
        parametros[:fecha_observaciones_pertinencia]=Time.now.utc
      end
      #Permite parsear el formato de nùmero para que el motor de base datos pueda almacenar nùmeros con punto (ex. 1.000). al momento se realiza para los montos de tipo moneda.-
      parametros[:monto_total_comprometido] = parametros[:monto_total_comprometido].gsub('.','') unless parametros[:monto_total_comprometido].nil?
      parametros[:ventas] = parametros[:ventas].gsub('.','') unless parametros[:ventas].nil?
      parametros[:monto_inversion] = parametros[:monto_inversion].gsub('.','') unless parametros[:monto_inversion].nil?
      parametros
    end

    def manifestacion_firma_params
      params.require(:manifestacion_de_interes).permit(
        :fecha_firma,
        :direccion_firma,
        :lat_firma,
        :lng_firma,
        :temporal,
        firma_archivo: [],
        firmantes: []
      )
    end


    def manifestacion_carga_audit_params
      params.require(:manifestacion_de_interes).permit(
        :archivo_carga_auditoria,
        :temporal
      )
    end

    #DZC 
    def manifestacion_terminar_diagnostico_params
      parametros=params(
        :observaciones_documentos_diagnostico
      )
      parametros[:diagnostico_fecha_termino]=Time.now.utc #agrega nuevo campo al hash, lo que permite instanciar ese campo en la tabla al momento de ejecutar el patch (update)
      parametros
    end

    # DZC APL-016 TERMINA TAREA Y ETAPA
    def manifestacion_terminar_negociacion_params
      parametros=params.require(:manifestacion_de_interes).permit(
        :comentarios_y_observaciones_negociacion_acuerdo
      )
      parametros[:fecha_termino_negociacion]=Time.now.utc #agrega nuevo campo al hash, lo que permite instanciar ese campo en la tabla al momento de ejecutar el patch (update)
      parametros
    end

    # DZC APL-023 TERMINA TAREA Y ETAPA
    def manifestacion_terminar_acuerdo_params
      parametros=params.require(:manifestacion_de_interes).permit(
        :comentarios_y_observaciones_termino_acuerdo
      )
      parametros[:fecha_termino_acuerdo]=Time.now.utc #agrega nuevo campo al hash, lo que permite instanciar ese campo en la tabla al momento de ejecutar el patch (update)
      parametros
    end

    def set_representantes
      usuario = User.find_by_id(@manifestacion_de_interes.representante_institucion_para_solicitud_id)
      resultado = Persona.por_institucion_cargo(@manifestacion_de_interes.contribuyente_id, Cargo::ENCARGADO_INS, usuario, true)
      @representantes = resultado[0]
      @nuevo_usuario = resultado[1]
    end  
end
